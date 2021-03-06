#!/usr/bin/perl -I /root/tgmanage
use strict;

BEGIN {
        require "include/config.pm";
        eval {
                require "include/config.local.pm";
        };
}


use Net::IP;
use Net::IP qw(:PROC);

unless ( (($#ARGV == 0 ) || ( $#ARGV == 1))
	&& (( $ARGV[0] eq "master" ) || ( $ARGV[0] eq "slave" )) )
{
	print STDERR "Invalid usage!\ncat netnames.txt | $0 <master|slave> [basedir]\n";
	exit 1;
}

my $role = $ARGV[0];

my $base = "/etc";
$base = $ARGV[1] if $#ARGV == 1;
$base .= "/" if not $base =~ m/\/$/ and not $base eq "";

my $bind_base =  $base . "bind/";
my $named_file = $bind_base . "named.conf";

if ( -f $named_file )
{
	print STDERR $named_file . " already exists. Cowardly refusing to continue\n";
	exit;
}

my $tgname    = $nms::config::tgname;

my $pri_a     = $nms::config::pri_a;
my $pri_ptr   = $nms::config::pri_ptr;
my $pri_v6    = $nms::config::pri_v6;

my $sec_a     = $nms::config::sec_a;
my $sec_ptr   = $nms::config::sec_ptr;
my $sec_v6    = $nms::config::sec_v6;
my $ipv6zone  = $nms::config::ipv6zone;
my $ext_xfer  = $nms::config::ext_xfer;
my $ext_ns    = $nms::config::ext_ns;

my $ddns_key  = $nms::config::ddns_key;

my $base_ipv4net    = $nms::config::base_ipv4net;
my $base_ipv4prefix = $nms::config::base_ipv4prefix;

my $base_ipv6net    = $nms::config::base_ipv6net;
my $base_ipv6prefix = $nms::config::base_ipv6prefix;

my $noc_nett = $nms::config::noc_nett;

my $ddns_to = $nms::config::ddns_to;

my $pxe_server = $nms::config::ddns_to;

my $run = `date +%Y%m%d-%H%M`;

open NFILE, ">" . $named_file or die ( $! . " " . $named_file );

chomp $run;
print NFILE <<EOF;
// This named.conf was generated by make-named.pl at $run
// The current version of make-named.pl should not overwrite this file.
acl tg-nett  { $base_ipv4net/$base_ipv4prefix; $base_ipv6net:/$base_ipv6prefix; 127.0.0.0/8; ::1; };
acl ns-xfr   { $ext_ns; $sec_ptr; $sec_v6; $pri_ptr; $pri_v6; $noc_nett; };
acl ripe-xfr { $ext_ns; $sec_ptr; $sec_v6; $pri_ptr; $pri_v6; $ext_xfer; };

options {
        directory "/etc/bind";
        allow-recursion { tg-nett; };
        allow-query { any; };
        allow-transfer { ns-xfr; };
        recursion yes;
        auth-nxdomain no;
        listen-on-v6 { any; };
};

key DHCP_UPDATER {
        algorithm HMAC-MD5.SIG-ALG.REG.INT;
        secret $ddns_key;
};
EOF

if ( $role eq "master" )
{
	print NFILE <<EOF;

zone "$tgname.gathering.org" {
        type master;
        file "$tgname.gathering.org.zone";
        notify yes;
        allow-transfer { ns-xfr; };
};

zone "infra.$tgname.gathering.org" {
        type master;
        file "infra.$tgname.gathering.org.zone";
        notify yes;
        allow-transfer { ns-xfr; };
};

zone "$ipv6zone" {
        type master;
        allow-update { key DHCP_UPDATER; };
        notify yes;
        file "$ipv6zone.zone";
        allow-transfer { ns-xfr; ripe-xfr; };
};

include "/etc/bind/named.conf.default-zones";
include "named.reverse4.conf";
include "named.master-include.conf";
EOF
}

if ( $role eq "slave" )
{
	print NFILE <<EOF;

masters bootstrap  { $pri_ptr; };

zone "$tgname.gathering.org" {
        type slave;
        file "slave/$tgname.gathering.org";
        notify no;
	masters { bootstrap; };
};

zone "infra.$tgname.gathering.org" {
        type slave;
        file "slave/infra.$tgname.gathering.org";
        notify no;
	masters { bootstrap; };
};

zone "$ipv6zone" {
        type slave;
        notify no;
	masters { bootstrap; };
        file "slave/$ipv6zone:";
        allow-transfer { ns-xfr; ripe-xfr; };
};

include "named.conf.default-zones";
include "named.slave-reverse4.conf";
include "named.slave-include.conf";
EOF
}
