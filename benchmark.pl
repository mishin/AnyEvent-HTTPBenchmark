#!/usr/bin/env perl
use common::sense; #new features in perl(not for 5.8.8 and older (; )
use AnyEvent::HTTP; # main module
use Time::HiRes; # to measure time
use Getopt::Long; # to command line parsing
use DateTime; # to make time human-readable :)
use Data::Dumper; # to see the date in debug
my $DEBUG = 0; #Debug mode. Default is false (0)
my $timeout = 60; 
my $count = 30000; #number of requests
my $concurency = 20; # number of parralle requests
my $done = 0; 
my $url = 'http://elementa.su/';# default url to test
my $method = 'GET'; #http method
my $proxy; # proxy server
my $file; #scenario file
my $max_recurse = 10; # the default recurse number;
my $useragent = 'Mozilla/5.0 (compatible; U; AnyEvent::HTTPBenchmark/0.03; +http://github.com/shafiev/AnyEvent-HTTPBenchmark)';

#arrays
my @reqs_time; # the times of requests

parse_command_line(); #parsing the command line arguments

$AnyEvent::VERBOSE = 10 if $DEBUG;
$AnyEvent::HTTP::MAX_PER_HOST = $concurency;
$AnyEvent::HTTP::set_proxy = $proxy;
$AnyEvent::HTTP::USERAGENT = $useragent; 

#on ctrl-c break run the end_bench sub.
$SIG{'INT'} = 'end_bench';

my $cv = AnyEvent->condvar; 

#start measuring time
my $start_time = Time::HiRes::time;
my $dt = DateTime->from_epoch( epoch => $start_time  );
print 'Started at ' .($dt->hms). '.' .($dt->millisecond);

#starting requests
for ( 1 .. $concurency ) 
{
    add_request($_, $url);
}

$cv->recv; # begin receiving message and make callbacks magic ;)
end_bench(); # call the end

#subs 
sub parse_command_line
{
    #get options which ovveride the default values
    my $result = GetOptions ("url=s" => \$url,
                             "n=i"   => \$count,
                             "c=i"   => \$concurency,
                             "debug" => \$DEBUG,
                             "proxy=s" => \$proxy,
                             "useragent=s" => \$useragent );    
}

sub add_request 
{
    my ($id, $url) = @_;

    my $req_time = Time::HiRes::time;
    http_request $method => $url, timeout => $timeout, sub 
    {
        my $completed = Time::HiRes::time;
        my $dtin = DateTime->from_epoch( epoch => ($completed-$req_time)  );
        print 'Got answer in '. $dtin->second . '.' . $dtin->millisecond .' seconds' . "\n";
        push( @reqs_time , ( ($dtin->second) .'.'. ($dtin->millisecond) ) );
        $done++;
        
        my $hdr = @_[1];
       
        if ( $hdr->{Status} =~ /^2/ )
        {
            print "done $done\n";
        }
        else
        {
            print "Oops we get problem in  request  . $done  . ($hdr->{Status}) . ($hdr->{Reason}) \n";
        }    
          
        return add_request($done, $url) if $done < $count;

        $cv->send;
    }
}


sub end_bench
{
    my $end_time = Time::HiRes::time;
    my $end_dt = DateTime->from_epoch( epoch => ($end_time - $start_time) );
    print 'It\'s takes the  ' . ($end_dt->second) .'.' .($end_dt->millisecond) ." seconds .\n";
    my $sum;
    
    #dirty hack to avoid division by zero ;)
    if ( ($end_dt->second) ==0 )
    { 
        print 'Requests per second  is ' . ( $count /($end_dt->millisecond) ) . "\n"; 
    }
    else
    {   
        print 'Requests per second  is ' . ( $count /( ($end_dt->minute)*60 + ($end_dt->second) )) . "\n";
    }       
    #sort by time
    @reqs_time = sort (@reqs_time);
    
    for my $i(0..scalar(@reqs_time) )
    {
        #calculate average time
        $sum +=$reqs_time[$i];
    }
    
    print "\nShortest is :  $reqs_time[0]  sec. \n";
    print "Average time is : ". ($sum/$count) . " sec. \n";
    print "Longest is :  $reqs_time[scalar(@reqs_time)-1] sec. \n";
    exit;
}

1;