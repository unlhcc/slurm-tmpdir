--[[
SLURM SPANK Lua plugin to set per-job TMPDIR

Tested with SLURM 2.4 on Scientific Linux 6

Requirements:
  - slurm-spank-plugins-lua
    http://code.google.com/p/slurm-spank-plugins/
  - lua-posix
    From EPEL
  - lua-linuxsys
    https://github.com/jthiltges/lua-linuxsys

At job start:
1) Create per-job temporary directories:
   a) /scratch/slurm_<jobid>
   b) /dev/shm/slurm_<jobid>
2) Unshare namespaces
   a) unshare CLONE_NEWNS
   b) unshare CLONE_NEWIPC
3) Bind mount directories for job:
     /scratch => /scratch/slurm_<jobid>
     /tmp     => /scratch/slurm_<jobid>/.tmp
     /var/tmp => /scratch/slurm_<jobid>/.var.tmp
     /dev/shm => /dev/shm/slurm_<jobid>
4) Set $TMPDIR = /tmp

At job completion:
1) Remove /scratch/slurm_<jobid>
2) Remove /dev/shm/slurm_<jobid>
--]]

local s = require 'linuxsys'
local p = require 'posix'

local scratch = '/scratch'

function job_scratch (spank, base)
  -- Job scratch is based on job ID
  local js = string.format('%s/slurm_%s', base,
    spank:get_item('S_JOB_ID')
  )
  return js
end

-- Called for each task just after fork,
-- but before elevated privileges are dropped permanently.
function slurm_spank_task_init_privileged (spank)
  local js = job_scratch(spank, scratch)
  local jm = job_scratch(spank, "/dev/shm")

  if js == nil then
    SPANK.log_info("Couldn't determine job scratch directory")
    return SPANK.FAILURE
  end

  SPANK.log_info("Using job scratch directory of %s", js)

  -- Make job scratch directories
  p.mkdir(js)
  p.mkdir(js .. '/.tmp')
  p.mkdir(js .. '/.var.tmp')
  -- Make job shared memory directory
  p.mkdir(jm)

  -- Set UID/GID (note: GID is not available in prolog)
  local uid = spank:get_item('S_JOB_UID')
  --gid = spank:get_item('S_JOB_GID')
  local gid = -1

  SPANK.log_info("Setting scratch uid = %d, gid = %d", uid, gid)
  p.chown(js .. '/.tmp',     uid, gid)
  p.chown(js .. '/.var.tmp', uid, gid)
  p.chown(js,                uid, gid)
  p.chown(jm,                uid, gid)

  -- Full access to owner for /scratch, no access otherwise
  --   (note: RHEL6 lua-posix cannot do suid/sgid/svtx)
  p.chmod(js,                'rwx------')
  -- Full access to all for $TMPDIR (glExec may switch uid/gid)
  p.chmod(js .. '/.tmp',     'rwxrwxrwx')
  p.chmod(js .. '/.var.tmp', 'rwxrwxrwx')

  -- Unshare namespaces
  s.unshare(s.CLONE_NEWNS)
  s.unshare(s.CLONE_NEWIPC)

  -- Bind mount the new targets
  s.mount(js .. '/.tmp',     '/tmp',     'none', s.MS_BIND)
  s.mount(js .. '/.var.tmp', '/var/tmp', 'none', s.MS_BIND)
  s.mount(js,                '/scratch', 'none', s.MS_BIND)
  s.mount(jm,                '/dev/shm', 'none', s.MS_BIND)

  -- Set $TMPDIR
  spank:setenv("TMPDIR", "/tmp", 1)

  -- We have a new IPC namespace which resets the various shared memory
  -- and message queue sizes to the defaults, which is too small.
  -- Call sysctl to set the values to what is in /etc/sysctl.conf again.
  SPANK.log_info('Calling (sysctl -q -e -p /etc/sysctl.conf) for new IPC namespace')
  os.execute('/sbin/sysctl -q -e -p /etc/sysctl.conf')

end

-- Called just before the job epilog.
function slurm_spank_job_epilog (spank)
  local js = job_scratch(spank, scratch)
  local jm = job_scratch(spank, "/dev/shm")

  if js == nil then
    SPANK.log_info("Couldn't determine job scratch directory")
    return SPANK.FAILURE
  end

  SPANK.log_info('Cleaning scratch directory ' .. js)
  os.execute('rm -rf --one-file-system ' .. js)
  SPANK.log_info('Cleaning /dev/shm directory ' .. jm)
  os.execute('rm -rf --one-file-system ' .. jm)

end
