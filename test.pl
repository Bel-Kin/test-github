#!/usr/bin/env perl
use strict;
use warnings;
use Date::Calc qw(Day_of_Week Day_of_Week_to_Text Delta_Days);
use JSON;
use LWP;
$|=1;

my $user = $ARGV[0];
if(!$user){
	print "Usage: test.pl <USERNAME>\n";
	exit;
}


my $gitUrl = 'https://api.github.com';
my ($url,$content);

# текущая дата
my (@dt) = localtime(time());
$dt[4] += 1; $dt[5] += 1900;
# условие: "Год назад от текущей даты следовало нам добавить. Например сегодня это с 27.12.2017 по 27.12.2018."
# нельзя просто взять 365, так как бывают високосные годы
# интервал в днях, за который нужны данные
my $delta_days = Delta_Days($dt[5]-1,$dt[4],$dt[3],$dt[5],$dt[4],$dt[3]);


my $BROWSER = LWP::UserAgent->new;
my $JSON = JSON->new;

# получаем репозитории пользователя
$url = "$gitUrl/users/$user/repos";
$content = request($url);
if($content){
	my $json_repo = $JSON->decode($content);
	foreach my $repo(@{$json_repo}){
	# проходим по репозиториям
#if($repo->{full_name} ne 'kraih/osc-plugin-factory'){ next; }
		$url = "$gitUrl/repos/".$repo->{full_name}.'/commits';
		$content = request($url);
		if($content){
			my %table;
			my $max_commit = 0;
			my $json_commit = $JSON->decode($content);
			foreach my $commit(@{$json_commit}){
			# проходим по коммитам репозитория
				my($year,$month,$day,$hour) = ($1,$2,$3,$4) if $commit->{commit}{committer}{date} =~ /^(\d{4})\-(\d{2})\-(\d{2})T(\d{2}):/;
				# интервал в днях от даты коммита до сегодня
				my $delta = Delta_Days($year,$month,$day,$dt[5],$dt[4],$dt[3]);
				if($delta <= $delta_days){
				# интервал входит в заданный
					# находим день недели, который был в дату коммита
					my $dowt = Day_of_Week_to_Text(Day_of_Week($year,$month,$day));
					$table{$dowt}{$hour}++;
					if($table{$dowt}{$hour} > $max_commit){
						$max_commit = $table{$dowt}{$hour};
					}
				}
			}
			print 'Repo "',$repo->{full_name},"\" commits for last $delta_days days: ";
			if(%table){
			# данные по коммитам есть, выводим красивую таблицу
			# строки - дни недели
			# столбцы - часы
				my $cell_length = length($max_commit);
				print "\n";
				line($cell_length);
				print "| days / hours ";
				for my $h('00'..'23'){
					print '|';
					for(1..$cell_length-2){ print ' '; }
					print " $h ";
				}
				print "|\n";
				line($cell_length);
				foreach my $d('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'){
					print "| $d";
					for(0..11-length($d)){ print ' '; }
					foreach my $h('00'..'23'){
						my $count = $table{$d}{$h} || '0';
						print " | ";
						my $length = $cell_length > 2 ? $cell_length : 2;
						for(1..$length-length($count)){ print ' '; };
						if($count > 0){ print "\x1b[32m"; }
						print $count;
						if($count > 0){ print "\x1b[0m"; }
					}
					print " |\n";
				}
				line($cell_length);
			}else{
			# данных по коммитам за заданный период нет
				print "None\n";
			}
		}
	}
}

exit;

#=====================
# выводим "линию"
#=================
sub line{
	my($max) = @_;
	my $length = $max > 2 ? $max : 2;
	print ' --------------';
	for(0..23){ for(0..$length+2){ print '-'; }}
	print "\n";
}
#=====================
# http запрос
#=================
sub request{
	my($url) = @_;
	my ($req,$res);

	$req = HTTP::Request->new('GET',$url);
	$res = $BROWSER->request($req);
	if(!$res->is_success){
		print "Bad request:\n\turl: $url\n\tcode: ",$res->status_line,"\n";
		return '';
	}
	return $res->content;
}
