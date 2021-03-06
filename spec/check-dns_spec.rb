#!/usr/bin/env ruby
#
# DOMAIN=sslip.io rspec --format documentation --color spec
#
# Admittedly it's overkill to use rspec to run a set of assertions
# against a DNS server -- a simple shell script would have been
# shorter and more understandable. We are using rspec merely to
# practice using rspec.
def get_whois_nameservers(domain)
  whois_output = `whois #{domain}`
  soa = nil
  whois_lines = whois_output.split(/\n+/)
  nameserver_lines = whois_lines.select { |line| line =~ /^Name Server:/ }
  nameservers = nameserver_lines.map { |line| line.split.last.downcase }
  # whois records don't have trail '.'; NS records do; add trailing '.'
  nameservers.map { |ns| ns << '.' }
  nameservers
end

def idn_dig?
  system("dig -h | grep idn")
end

domain = ENV['DOMAIN'] || 'example.com'
whois_nameservers = get_whois_nameservers(domain)

describe domain do
  soa = nil
  idn_dig = `dig -h | grep idn`
  dig_args = "+short"
  dig_args += idn_dig? ? " +noidnin" : ""


  context "when evaluating $DOMAIN (\"#{domain}\") environment variable" do
    let (:domain) { ENV['DOMAIN'] }
    it 'is set' do
      expect(domain).not_to be_nil
    end
    it 'is not an empty string' do
      expect(domain).not_to eq('')
    end
  end

  it "should have at least 2 nameservers" do
    expect(whois_nameservers.size).to be > 1
  end

  whois_nameservers.each do |whois_nameserver|
    it "nameserver #{whois_nameserver}'s NS records match whois's, " +
      "`dig #{dig_args} ns sslip.io @#{whois_nameserver}`" do
      dig_nameservers = `dig #{dig_args} ns sslip.io @#{whois_nameserver}`.split(/\n+/)
      expect(dig_nameservers.sort).to eq(whois_nameservers.sort)
    end

    it "nameserver #{whois_nameserver}'s SOA record match" do
      dig_soa = `dig #{dig_args} soa sslip.io @#{whois_nameserver}`
      soa = soa || dig_soa
      expect(dig_soa).to eq(soa)
    end

    a = [ rand(256), rand(256), rand(256), rand(256) ]
    it "nameserver #{whois_nameserver} resolves #{a.join(".")}.sslip.io to #{a.join(".")}" do
      expect(`dig #{dig_args} #{a.join(".") + "." + domain} @#{whois_nameserver}`.chomp).to  eq(a.join("."))
    end

    a = [ rand(256), rand(256), rand(256), rand(256) ]
    it "nameserver #{whois_nameserver} resolves #{a.join("-")}.sslip.io to #{a.join(".")}" do
      expect(`dig #{dig_args} #{a.join("-") + "." + domain} @#{whois_nameserver}`.chomp).to  eq(a.join("."))
    end

    a = [ rand(256), rand(256), rand(256), rand(256) ]
    b = [ ('a'..'z').to_a, ('0'..'9').to_a ].flatten.shuffle[0,8].join
    it "nameserver #{whois_nameserver} resolves #{b}.#{a.join("-")}.sslip.io to #{a.join(".")}" do
      expect(`dig #{dig_args} #{b}.#{a.join("-") + "." + domain} @#{whois_nameserver}`.chomp).to  eq(a.join("."))
    end

    a = [ rand(256), rand(256), rand(256), rand(256) ]
    b = [ ('a'..'z').to_a, ('0'..'9').to_a ].flatten.shuffle[0,8].join
    it "nameserver #{whois_nameserver} resolves #{a.join("-")}.#{b} to #{a.join(".")}" do
      expect(`dig #{dig_args} #{a.join("-") + "." + b} @#{whois_nameserver}`.chomp).to  eq(a.join("."))
    end

    # don't begin the hostname with a double-dash -- `dig` mistakes it for an argument
    it "nameserver #{whois_nameserver} resolves api.--.sslip.io' to eq ::)}" do
      expect(`dig #{dig_args} AAAA api.--.sslip.io @#{whois_nameserver}`.chomp).to eq("::")
    end

    it "nameserver #{whois_nameserver} resolves localhost.--1.sslip.io' to eq ::1)}" do
      expect(`dig #{dig_args} AAAA localhost.api.--1.sslip.io @#{whois_nameserver}`.chomp).to eq("::1")
    end

    it "nameserver #{whois_nameserver} resolves 2001-4860-4860--8888.sslip.io' to eq 2001:4860:4860::8888)}" do
      expect(`dig #{dig_args} AAAA 2001-4860-4860--8888.sslip.io @#{whois_nameserver}`.chomp).to eq("2001:4860:4860::8888")
    end

    it "nameserver #{whois_nameserver} resolves 2601-646-100-69f0--24.sslip.io' to eq 2601:646:100:69f0::24)}" do
      expect(`dig #{dig_args} AAAA 2601-646-100-69f0--24.sslip.io @#{whois_nameserver}`.chomp).to eq("2601:646:100:69f0::24")
    end
  end
end
