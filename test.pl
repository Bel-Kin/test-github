#!/usr/bin/env perl
use strict;
use warnings;
use Date::Calc qw(Day_of_Week Day_of_Week_to_Text Delta_Days);
use JSON;
use LWP;
$|=1;

my $user = $ARGV[0];
if (!$user){
	print "Usage: test.pl <USERNAME>\n";
	exit;
}

my $git_url = 'https://api.github.com';
my ($url, $content);

my (@dt) = localtime(time());
$dt[4] += 1; $dt[5] += 1900;
my $delta_days = Delta_Days($dt[5]-1, $dt[4], $dt[3], $dt[5], $dt[4], $dt[3]);

my $BROWSER = LWP::UserAgent->new;
my $JSON = JSON->new;

$url = "$git_url/users/$user/repos";
$content = request(url=>$url);

if ($content){
	my $json_repo = $JSON->decode($content);
	for my $repo(@{$json_repo}){

		my ($is_data, $max_commit, $page, %table) = (1, 0, 0, ());

		while ($is_data){

			$url = "$git_url/repos/".$repo->{full_name}.'/commits?per_page=1000'.($page ? "&page=$page" : '');
			$content = request(url=>$url);

			$is_data = 0;
			if ($content){
				my $json_commit = $JSON->decode($content);
				for my $commit(@{$json_commit}){
					my ($year, $month, $day, $hour);
					($year, $month, $day, $hour) = ($1, $2, $3, $4) if $commit->{commit}{committer}{date} =~ /^(\d{4})\-(\d{2})\-(\d{2})T(\d{2}):/;
					if (defined $year){
						my $delta = Delta_Days($year, $month, $day, $dt[5], $dt[4], $dt[3]);
						if ($delta >= 0 and $delta <= $delta_days){
							my $dowt = Day_of_Week_to_Text(Day_of_Week($year, $month, $day));
							$table{$dowt}{$hour}++;
							$max_commit = $table{$dowt}{$hour} if ($table{$dowt}{$hour} > $max_commit);
						}
					}
					$is_data = 1;
				}
			}

			$page++ if $is_data;
		}

		print 'Repo "',$repo->{full_name},"\" commits for last $delta_days days: ";
		if(%table){
			my $cell_length = length($max_commit);
			print "\n";
			line($cell_length);
			print "| days / hours ";
			for my $h('00'..'23'){
				print '|';
				print ' ' for (1..$cell_length-2);
				print " $h ";
			}
			print "|\n";
			line($cell_length);
			for my $d('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'){
				print "| $d";
				print ' ' for (0..11-length($d));
				for my $h('00'..'23'){
					my $count = $table{$d}{$h} || '0';
					print " | ";
					my $length = $cell_length > 2 ? $cell_length : 2;
					print ' ' for (1..$length-length($count));
					print "\x1b[32m" if ($count > 0);
					print $count;
					print "\x1b[0m" if ($count > 0);
				}
				print " |\n";
			}
			line($cell_length);
		}else{
			print "None\n";
		}
	}
}

exit;

sub line{
	my($max) = @_;
	my $length = $max > 2 ? $max : 2;
	print ' --------------';
	for (0..23){
		print '-' for (0..$length+2);
	}
	print "\n";
}

sub request{
	my(%data) = @_;
	my ($req,$res);
	my $headers = HTTP::Headers->new;
	if (exists $data{headers}){
		for my $h(keys %{$data{headers}}){
			$headers->header($h => $data{headers}{$h});
		}
	}
	$req = HTTP::Request->new('GET',$data{url},$headers);
	$res = $BROWSER->request($req);
	if (!$res->is_success){
		print "Bad request:\n\turl: $data{url}\n\tstatus: ",$res->status_line,"\n";
		return '';
	}
	return $res->content;
}
