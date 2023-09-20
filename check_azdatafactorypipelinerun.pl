#!/usr/bin/perl -w
#===============================================================================
# Script Name   : check_azdatafactorypipelinerun.pl
# Usage Syntax  : ./check_azdatafactorypipelinerun.pl [-v] -t <TENANTID> -i <CLIENTID> -s <SUBID> -p <CLIENTSECRET> -T <INTERVAL> -d <DATAFACTORY> -P <PIPELINE>
# Author        : Start81 (DESMAREST JULIEN)
# Version       : 1.2.0
# Last Modified : 06/09/2023
# Modified By   : Start81 (DESMAREST JULIEN) 
# Description   : Check Azure Data Factory job status
# Depends On    : REST::Client, Data::Dumper, DateTime, Getopt::Long, JSON, Switch
#
# Changelog:
#    Legend:
#       [*] Informational, [!] Bugix, [+] Added, [-] Removed
#
# - 11/06/2021 | 1.0.0 | [*] initial realease
# - 11/06/2021 | 1.1.0 | [+] Add Pipeline parameter check
# - 02/08/2021 | 1.1.1 | [!] Bug fix when getting last pipeline run
# - 21/10/2021 | 1.1.2 | [!] Bug fix when getting run list => Content-Type = 'application/json'
# - 02/11/2021 | 1.1.3 | [!] Bug fix when display the error message
# - 06/09/2023 | 1.2.0 | [+] save authentication token for next call
#===============================================================================
use REST::Client;
use Data::Dumper;
use JSON;
use DateTime;
use Getopt::Long;
use Switch;
use File::Basename;
use strict;
use warnings;
use Readonly;
Readonly our $VERSION => '1.2.0';
my $o_verb;
my $o_tenantid;
my $o_clientid;
my $o_clientsecret;
my $o_subid;
my $o_datafactory_name;
my $o_pipeline_name;
my $o_help;
my $o_time_interval;
my $script_name = basename($0);

my %errors = ('OK' => 0, 'WARNING' => 1, 'CRITICAL' => 2, 'UNKNOWN' => 3);

sub verb { my $t = shift; print $t, "\n" if defined($o_verb); return 0};

sub print_usage {
    print "Usage: $script_name [-v] -t <TENANTID> -i <CLIENTID> -s <SUBID> -p <CLIENTSECRET> -T <INTERVAL> -d <DATAFACTORY> -P <PIPELINE>\n";
    return 0;
}

sub help {
    print "Check Azure pipeline run status  $VERSION\n";
    print_usage();
    print <<'EOT'; 
-v, --verbose
    print extra debugging information
-h, --help
    print this help message
-t, --tenantid=<TENANTID>
    The GUID of the tenant to be checked (required)
-i, --clientid=<CLIENTID>
    The GUID of the registered application (required)
-s, --subid=<SUBID>
    The GUID of the Subscription (required)
-p, --clientsecret=<CLIENTSECRET>
    Access Key of registered application (required)
-d, --datafactory=<DATAFACTORY>
    datafactory name.
-P, --Pipeline=<PIPELINE>
    Pipeline name
-T, --Timeinterval=<INTERVAL>
    Interval in hour this is used to calculate the filter :
    lastUpdatedAfter = now() - Timeinterval
    lastUpdatedBefore = now()
EOT
    return 0
}

#write content in a file
sub write_file {
    my ($content,$tmp_file_name) = @_;
    my $fd;
    verb("write $tmp_file_name");
    if (open($fd, '>', $tmp_file_name)) {
            print $fd $content;
            close($fd);       
    } else {
        print("UNKNOWN unable to write file $tmp_file_name");
        exit $errors{"UNKNOWN"};
    }
    
    return 0
}

#Read previous token  
sub read_token_file {
    my ($tmp_file_name) = @_;
    my $fd;
    my $token ="";
    verb("read $tmp_file_name");
    if (open($fd, '<', $tmp_file_name)) {
        while (my $row = <$fd>) {
            chomp $row;
            $token=$token . $row;
        }
        close($fd);
    } else {
        print("UNKNOWN unable to wread $tmp_file_name");
        exit $errors{"UNKNOWN"};
    }
    return $token
    
}

#get a new acces token
sub get_access_token{
    my ($clientid,$clientsecret,$tenantid) = @_;
    #Get token
    my $client = REST::Client->new();
    my $payload = 'grant_type=client_credentials&client_id=' . $clientid . '&client_secret=' . $clientsecret . '&resource=https%3A//management.azure.com/';
    my $url = "https://login.microsoftonline.com/" . $tenantid . "/oauth2/token";
    $client->POST($url,$payload);
    if ($client->responseCode() ne '200') {
        print "UNKNOWN response code : " . $client->responseCode() . " Message : Error when getting token" . $client->{_res}->decoded_content;
        exit $errors{'CRITICAL'};
    }
    return $client->{_res}->decoded_content;
}

sub check_options {
    Getopt::Long::Configure("bundling");
    GetOptions(
        'v' => \$o_verb, 'verbose' => \$o_verb,
        'h' => \$o_help, 'help' => \$o_help,
        't:s' => \$o_tenantid, 'tenantid:s' => \$o_tenantid,
        'i:s' => \$o_clientid, 'clientid:s' => \$o_clientid,
        's:s' => \$o_subid, 'subid:s' => \$o_subid,
        'p:s' => \$o_clientsecret, 'clientsecret:s' => \$o_clientsecret,
        'd:s' => \$o_datafactory_name, 'datafactory:s' => \$o_datafactory_name,
        'P:s' => \$o_pipeline_name, 'Pipeline:s' => \$o_pipeline_name,
        'T:s' => \$o_time_interval, 'Timeinterval:s' => \$o_time_interval,
    );
    if (defined($o_help)) { help(); exit $errors{"UNKNOWN"}};

    if (!defined($o_tenantid)) {
        print "tenantid missing\n";
        print_usage();
        exit $errors{"UNKNOWN"};
    }
    if (!defined($o_clientid)) {
        print "clientid missing\n";
        print_usage();
        exit $errors{"UNKNOWN"};
    }
    if (!defined($o_subid)) {
        print "subid missing\n";
        print_usage();
        exit $errors{"UNKNOWN"};
    }
    if (!defined($o_clientsecret)) {
        print "clientsecret missing\n";
        print_usage();
        exit $errors{"UNKNOWN"};
    }
    if (!defined($o_datafactory_name)) {
        print "datafactory name missing\n";
        print_usage();
        exit $errors{"UNKNOWN"};
    }
    if (!defined($o_pipeline_name)) {
        print "pipeline name missing\n";
        print_usage();
        exit $errors{"UNKNOWN"};
    }
    if (!defined($o_time_interval)) {
        print "Time interval missing\n";
        print_usage();
        exit $errors{"UNKNOWN"};
    }
}

my $i = 0;
my $j = 0;
my $exit_code = $errors{"UNKNOWN"};
my $factory_name;
my $factory_id;
my $factory_found = 0;
my $msg_ok = "";
my $msg = "";
my @factory_list;

check_options;

my $subid = $o_subid;
my $tenantid = $o_tenantid;
my $clientid = $o_clientid;
my $clientsecret = $o_clientsecret;
my $end_date_to_query = DateTime->now;
$end_date_to_query->set_time_zone('UTC');
my $str_end_date = $end_date_to_query->ymd . "T" . $end_date_to_query->hms . "Z";
my $begin_date_to_query = DateTime->now;
$begin_date_to_query->set_time_zone('UTC');
$begin_date_to_query->subtract(hours => $o_time_interval);
my $str_begin_date = $begin_date_to_query->ymd . "T" . $begin_date_to_query->hms . "Z";

verb(" subid = " . $subid);
verb(" tenantid = " . $tenantid);
verb(" clientid = " . $clientid);
verb(" clientsecret = " . $clientsecret);

#Get token

my $tmp_file = "/tmp/$clientid.tmp";
my $token;
my $token_json;
if (-e $tmp_file) {
    #Read previous token
    $token = read_token_file ($tmp_file);
    $token_json = from_json($token);
    #check token expiration
    my $expiration = $token_json->{'expires_on'} - 60;
    my $current_time = time();
    if ($current_time > $expiration ) {
        #get a new token
        $token = get_access_token($clientid,$clientsecret,$tenantid);
        write_file($token,$tmp_file);
        $token_json = from_json($token);
    }
} else {
        $token = get_access_token($clientid,$clientsecret,$tenantid);
        write_file($token,$tmp_file);
        $token_json = from_json($token);;
}
$token = $token_json->{'access_token'};
verb("Authorization :" . $token);
my $client = REST::Client->new();
#Get datafactory  list

$client->addHeader('Authorization', 'Bearer ' . $token);
$client->addHeader('Content-Type', 'application/json;charset=utf8');
$client->addHeader('Accept', 'application/json');
my $url = "https://management.azure.com/subscriptions/$subid/providers/Microsoft.DataFactory/factories?api-version=2018-06-01";
$client->GET($url);
if ($client->responseCode() ne '200') {
    print "UNKNOWN response code : " . $client->responseCode() . " Message : Error when getting resource groups list" . $client->responseContent();
    exit $errors{'UNKNOWN'};
}
my $response_json = from_json($client->responseContent());
verb(Dumper($response_json));

$msg = "";
my $nb_queued = 0;
while (exists $response_json->{'value'}->[$i]) {
    $factory_name = $response_json->{'value'}->[$i]->{"name"};
    if ($factory_name eq $o_datafactory_name) {
        $factory_found = 1;
        $factory_id = $response_json->{'value'}->[$i]->{"id"};
        $url = "https://management.azure.com" . $factory_id . "/queryPipelineRuns?api-version=2018-06-01";
        verb($url);
        #filter in the request body
        #between 2 date
        #pipeline name
        #sort by RunStart

        my $body = '{'
        .'lastUpdatedAfter: "' . $str_begin_date . '",'
        .'lastUpdatedBefore: "' . $str_end_date . '",'
        . '  "filters": ['
        . '      {'
        . '          "operand": "PipelineName",'
        . '           "operator": "Equals",'
        . '            "values": ['
        . '                "' . $o_pipeline_name . '"'
        . '           ]'
        . '       },'
        . '   ],'
        . '   "orderBy": [{"orderBy": "RunStart", "order": "DESC"}]'
        .'}';
        verb($body);
        $client->addHeader('Content-Type', 'application/json');
        $client->POST($url, $body);
        if($client->responseCode() ne '200'){
            print "UNKNOWN response code : " . $client->responseCode() . " Message : Error when apply filter " . $body . " response : "  .$client->responseContent () ;
            exit $errors{'UNKNOWN'};
        }
        $response_json = from_json($client->responseContent());
        verb(Dumper($response_json));
        if (!defined($response_json->{'value'}->[0])) {
            print "UNKNOWN empty response for the time interval and pipeline name\n";
            exit 3;
        }
        while (exists $response_json->{'value'}->[$j]) {
            #Status
            # Queued
            # InProgress
            # Succeeded
            # Failed
            # Canceling
            # Canceled
            switch($response_json->{'value'}->[$j]->{'status'}) {
                case "Queued" {
                    $nb_queued++;
                }
                case "InProgress" {
                    $msg = "OK : pipelineName " . $o_pipeline_name . " " . $response_json->{'value'}->[$j]->{'status'};
                    $msg = $msg . " runStart : " . $response_json->{'value'}->[$j]->{'runStart'};
                    print $msg . "\n";
                    exit $errors{'OK'};
                }
                case "Succeeded" {
                    $msg = "OK : pipelineName " . $o_pipeline_name . " " . $response_json->{'value'}->[$j]->{'status'};
                    $msg = $msg . " runStart : " . $response_json->{'value'}->[$j]->{'runStart'};
                    $msg = $msg . " runEnd : " . $response_json->{'value'}->[$j]->{'runEnd'};
                    print $msg . "\n";
                    exit $errors{'OK'};
                }
                case "Failed" {
                    $msg = "CRITICAL : pipelineName " . $o_pipeline_name . " " . $response_json->{'value'}->[$j]->{'status'};
                    $msg = $msg . " runStart : " . $response_json->{'value'}->[$j]->{'runStart'};
                    $msg = $msg . " runEnd : " . $response_json->{'value'}->[$j]->{'runEnd'};
                    $msg = $msg . " Message : " . $response_json->{'value'}->[$j]->{'message'};
                    print $msg . "\n";
                    exit $errors{'CRITICAL'};
                }
                case "Canceling" {
                    $msg = "WARNING : pipelineName " . $o_pipeline_name . " " . $response_json->{'value'}->[$j]->{'status'};
                    print $msg . "\n";
                    exit $errors{'WARNING'};
                }
                case "Canceled" {
                    $msg = "WARNING : pipelineName " . $o_pipeline_name . " " . $response_json->{'value'}->[$j]->{'status'};
                    print $msg . "\n";
                    exit $errors{'WARNING'};
                }
            }
            $j++;
        }
        $msg = "OK : " . $nb_queued . " pipeline run Queued";
        print $msg . "\n";
        exit $errors{'OK'};
    } else {
        push(@factory_list, $factory_name);
    }
    $i++;
}
if ($factory_found != 1) {
    $msg = "UNKNOWN : datafactory " . $o_datafactory_name . " not found. Available are: " . join(", ", @factory_list);
    print $msg;
    exit $errors{"UNKNOWN"};
}
