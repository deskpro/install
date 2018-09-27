require '/tmp/kitchen/spec/spec_helper.rb'

describe file('/var/lib/deskpro/') do
  it { should be_directory }
end

describe file('/var/log/deskpro/') do
  it { should be_directory }
end

describe file('/usr/share/deskpro/') do
  it { should be_directory }
end

describe file('/etc/deskpro/') do
  it { should be_directory }
end

describe file('/srv/deskpro/') do
  it { should be_directory }
  it { should be_owned_by 'deskpro' }
  it { should be_grouped_into 'deskpro' }
end

describe command('ssh-keygen -f /etc/ssh/ssh_known_hosts -F github.com') do
  its(:stdout) { should match /Host github.com found/ }
  its(:exit_status) { should eq 0 }
end

describe user('deskpro') do
  it { should exist }
  it { should have_home_directory '/home/deskpro' }
  it { should belong_to_primary_group 'deskpro' }
end
