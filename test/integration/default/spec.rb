describe port(80) do
  it { should be_listening }
  its('processes') { should eq ['nginx'] }
  its('addresses') { should include '0.0.0.0' }
end

describe port(3306) do
  it { should be_listening }
  its('processes') { should cmp 'mysqld' }
  its('protocols') { should cmp 'tcp' }
  its('addresses') { should cmp '127.0.0.1' }
end

res = command('sudo -u deskpro /usr/share/nginx/html/deskpro/bin/console dp:web-server-info')
match = /Requirements Check   (http:\/\/.*)$/.match(res.stdout.lines[5])
address = match.captures[0].sub('deskpro-dev', 'localhost')

describe http(address) do
  its('status') { should eq 200 }
  its('body') { should_not match 'recommended that you fix the following' }
  its('body') { should match 'All checks passed successfully. Your system is ready to run Deskpro.' }
end

