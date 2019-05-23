
# Mikey's CRON Library
## A library for a CRON-style feature in your Levure project
CRON pulls its schedule from a single "crontab" file, and updates that same file each time that a job achieves with the next earliest time the job should be run again.
CRON is designed to be used as a library in Levure projects.

## Contents

* [Background](#background)
* [Installation](#installation)
* [Initializing CRON](#initializing)
* [Specifying settings in app.yml](#app.yml-parameters)
* [Crontab format](#crontab-file-format)
* [Adding CRON to your crontab file](#adding-cron-to-your-crontab-file)
* [Logging](#logging)
* [API](#api)

#### Background
CRON will read the crontab file each time it launches, thus it is possible to manually update the schedule by updating the file.
CRON will determine which jobs are due to launch, and then sort them first by the (optional) priority you can assign, then by when the job is scheduled to launch.
CRON will udpate the crontab file after each job achieves to schedule the next run of that job.
CRON will then go to sleep until the next job is scheduled.  During this interval, you can manually awaken CRON by executing the ```cron``` command.
You can similarly schedule CRON to wake and run occasionally, even if there is no job scheduled, by [adding a cron event to your crontab file](#adding-cron-to-your-crontab-file).

As LiveCode is single-threaded, CRON will only be able to launch a single job at a time.
It will check the ```waitDepth``` to make sure no other tasks or handlers are pending or in process before launching a job.


## Installation
Whether submoduling or just installing the library, the path to use is ```app/libraries/cron```


## Initializing
The library will auto-initialize with any other libraries in your ```app/libraries``` directory


## app.yml parameters
To pre-configure CRON with your ```app.yml``` file.
1. First, add a ```cron``` section
2. Next, any of the following subkeys can be assigned (all are optional).

|  Type  |  Description  |
|------------|---------------|
| `retrySeconds` | How long to wait to see if it's ok to launch a job in seconds (default 60) |
| `path` | Path to the ```crontab.txt``` file relative to ```app.yml``` (default ./assets/crontab.txt) |
| `logType` | The type/label CRON will use when logging messages (default ```cron```) |

### Example:
```
#app.yml

cron:
   retrySeconds: 30
   path: ~/someRandomFolder/my_cronjobs.txt
   logType: someRandomType
```


## Crontab File Format
By default, CRON will assume that its tasks are located in the ```./assets/crontab.txt``` file.  You can override that setting in the ```app.yml``` file.
The file is tab/linefeed delimited (tab/carriage-return on windows)
*"Column" names below do not have special meaning.*
Columns are:

|  Column  |  Description  |
|------------|---------------|
| Enabled | (optional) If the column is not empty, the job is enabled.  If the column is empty, the job is disabled. |
| Event Name | Name of the job - must be unique. |
| Priority | (optional) Alphanumeric value used to sort jobs when multiple jobs are ready to be launched.  Priority does not have to be unique. |
| Launch After | The earliest the job should next launch.  DateItems are used as they are easier to read and manually write than some other date/time formats, such as seconds.  The dateItems format is year,month,day,hour,minute,second,dayOfTheWeek (but dayOfTheWeek is for informational purposes only, and has no effect on anything).  Timezone is assumed to be local.  |
| Action | LiveCode command CRON should execute |
| Next Run | Number of seconds after previous run achieves before job should launch again. |
| Comment | The rest of the line is ignored and may be used for comments. |

### Example:
```
X	pinger		2019,5,21,22,38,26,3	put "heartbeat"	60	#I included the "#" just to make the comment easier to spot, but it is unnecessary.
:-)	test	1	2019,05,22,08,00,00,4 sendEmail	38400			DateItems are year,month,day,hour,minute,second,dayOfTheWeek (but dayOfWeek doesn't do anything, so don't worry about setting it)
Enabled	hello	1	2019,05,22,08,00,00,4 someScriptToCall 3600		In this case, we will have a tie since the priority and launch-after times are the same, so CRON will choose the order.
Yep	smile ABC	2019,05,21,23,00,00,3 put "smile"	300	Notice that you can also use strings in your priority/sort order
	boomies		2018,07,04,22,00,00,0	send "lightFuse" to button "Launch Fireworks" of card "Independence Day" of stack "Celebration"	0	Since the first column is empty, this job is disabled.
```

## Adding CRON to your crontab file
If for whatever reason you want to supplement CRON's scheduling so that it runs periodically whether it thinks it needs to or not, you can add the following line to your crontab file (for example):
```
X	Extra CRON		1969,12,31,19,0,0,4	cron	3600	Makes CRON run hourly whether it needs to or not
```
This will not stop CRON from launching when it thinks it has a job to do, it will simply ensure that it also runs at whatever interval you set.

*Discussion:*
• Anything but empty in the first item enables the job.
• I called my job "Extra CRON", just because.  There is no reason why you can't just call it "cron", if you wish.
• The priority is optional, so I left it alone.  You could make it "Z" or "999999", etc. to give it a lower priority than your other jobs if you wish.
• The "Run After DateItems" column is just some time in the past so my Extra CRON job gets into the schedule.
• "cron" is the command being called
• 3600 seconds is one hour.
• The rest is comment.

## Logging
CRON uses the Levure logging functions.  It will post messages using the ```cron``` log type by default, although you can override that in the ```app.yml``` file.
CRON will log everything that it does, from starting, to the job it is going to execute, to the job achieving, to the upcoming schedule.

To activate logging for CRON, add
```
loggerAddType "cron"
```
in your code.

To stop logging for CRON, add
```
loggerRemoveType "cron"
```


## API

 - **cron**
That's it.  Call ```cron```.  It loads cronjobs from the crontab table and fires them off as needed.

You can also manually invoke ```cron``` at any time to force it to re-read your crontab file and reschedule jobs.  Otherwise, CRON will sleep until what it thinks is its next-scheduled job.

You can also schedule CRON to run regularly, even if no other job is scheduled to run, by [adding cron to your crontab file](#adding-cron-to-your-crontab-file).

