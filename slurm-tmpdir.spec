Name:           slurm-tmpdir
Version:        1.0
Release:        2%{?dist}
Summary:        Private tmp directories for Slurm

Group:          Applications/System
License:        Apache 2.0
URL:            https://github.com/djw8605/slurm-tmpdir
Source0:        %{name}-%{version}.tar.gz

Requires:       slurm
Requires:       lua
Requires:       lua-linuxsys
Requires:       slurm-plugins-lua

%description
Private tmp directories for Slurm

%prep
%setup -q


%build

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/%{_sysconfdir}/slurm/lua.d/
cp src/tmpdir.lua $RPM_BUILD_ROOT/%{_sysconfdir}/slurm/lua.d/tmpdir.lua

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%{_sysconfdir}/slurm/lua.d/tmpdir.lua



%changelog
* Tue Mar 22 2016 Derek Weitzel <djw8605@gmail.com> - 1.0-2
- Adding slurm-plugins-lua as dependency

* Tue Mar 22 2016 Derek Weitzel <djw8605@gmail.com> - 1.0-1
- Initial creation of RPM

