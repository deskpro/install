describe command('fgconsole') do
  its('stdout') { should eq "1\n" }
end

describe service('deskpro-boot-screen') do
  it { should be_installed }
  it { should be_enabled }
  it { should be_running }
end

describe processes('python3 /usr/bin/deskpro-vm-config') do
  it { should exist }
  its('users') { should eq ['root'] }
  its('tty') { should eq ['tty1'] }
end

# this is the sha256sum of the "welcome" screen. They are different because the
# terminal size in each system is different
sha256sum = case os[:name]
  when 'centos' then '076ea0a38faedb3b41cca5e6dd997a22545d9a8d8774fb07f2821cfc9565b5e3'
  when 'debian', 'ubuntu' then '1b31d6c7e543fbf6d19769126dbf67acc225dd595eaa639e1e3a69f5645c8d9d'
  else 'INVALID-SHA256SUM'
end

describe file('/dev/vcs') do
  its('sha256sum') { should eq sha256sum }
end
