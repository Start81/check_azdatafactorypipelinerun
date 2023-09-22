# check_azdatafactorypipelinerun

check azure datafactory job result

### prerequisites
This script uses theses libs : REST::Client, Data::Dumper, DateTime, Getopt::Long, JSON, Switch

to install them you can use cpan :

```
sudo cpan REST::Client Data::Dumper DateTime Getopt::Long JSON Switch
```
### use case

```bash
Check Azure pipeline run

Usage: check_azdatafactorypipelinerun.pl [-v] -t <TENANTID> -i <CLIENTID> -s <SUBID> -p <CLIENTSECRET> -T <INTERVAL> -d <DATAFACTORY> -P <PIPELINE>

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
```

sample  :

```bash
check_azdatafactorypipelinerun.pl --tenantid=<TENANTID> --clientid=<CLIENTID> --subid=<SUBID> --clientsecret=<CLIENTSECRET> --datafactory=MyDataFactory --Pipeline="MyPipeline" --Timeinterval=740
```
you may get  :

```bash
Ok : pipelineName MyPipeline Succeeded runStart : 2021-05-26T08:30:00.0161584Z runEnd : 2021-05-26T12:00:09.7422132Z
```
