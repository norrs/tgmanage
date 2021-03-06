#!/usr/bin/perl -I /srv/streamlib

use warnings;
use strict;

use stream;
use stream::config;
use CGI;
my $client = CGI->new;

my $stream = $client->param('stream');
my $interlaced = $client->param('interlaced');
my $delivery = $client->param('delivery');

my $v4net = $stream::config::v4net;
my $v6net = $stream::config::v6net;
my $multicast_ip = $stream::config::multicast;
my $tg = $stream::config::tg;
my $base_url = $stream::config::vlc_base_host;
my %streams = %stream::config::streams;



#default
if (not defined $delivery) {
	$delivery = "multicast";
}

if((not defined $stream) or (not defined $delivery)) {
	print $client->header();
	die "No stream and/or delivery method, robots unhappy :/\n";
}

my $url = "";
my $port_del = "";
my $port_str = "";
my $extinf = "";
my $flash_appendix = "";

my $clip = $client->remote_addr();

if (exists($streams{$stream})) {
	my $is_multicast = 0;
	# add force is_ip_local in check? 
	$is_multicast = 1	if (exists($streams{$stream}->{has_multicast}) && $delivery eq "multicast");

	if ($is_multicast) {
		$port_del = 20;
		$extinf .= "Multicasted";
		$url = $streams{$stream}->{multicast_ip};
	} else {
		$port_del = 30;
		$extinf .= "Unicasted";
		$url = $base_url;
		
		if ($streams{$stream}->{is_flash}) {
			$port_del = 50;
			$flash_appendix = "/stream.flv";
		}
	}

	$port_del = $streams{$stream}->{preport} if (defined($streams{$stream}->{preport}));
	$port_str = $streams{$stream}->{port};
	$extinf .= " $streams{$stream}->{title}";
		 
} else {
	 &error("No stream and/or delivery method, robots unhappy :-/");
}

#print out new file
print $client->header(-type => "application/vlc",
			"-Content-disposition" => "attachment; filename=tg-".$delivery."-".$stream.".vlc"
);

print "#EXTM3U\n";
print "#EXTINF:-1,TG$tg $extinf\n";
if(defined $interlaced && $interlaced == 1) {
	print "#EXTVLCOPT:deinterlace=1\n";
	print "#EXTVLCOPT:deinterlace-mode=linear\n";
}
print "$url:$port_del$port_str$flash_appendix\n";

sub error($) {
	my $message = shift;
	print $client->header();
	die($message."\n");
}
