# Mikey's CRON Library



## A library for a CRON-style feature in your Levure project

CRON  can pull its schedule from a single "crontab" file, and update that same file each time that a job achieves with the next earliest time the job should be run again.

It can also be run in "manual" mode, whereby all jobs must be manually added via the [API](#api)

CRON is designed to be used as a library in Levure projects.



## Version History

[Before you download/install a new version, make sure you aren't going to break your code](Version History.md)



## Contents

* [Background](#background)
* [CAUTION](#caution)
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
CRON will then go to sleep until the next job is scheduled.  During this interval, you can manually awaken CRON by executing the `cron` command.
You can similarly schedule CRON to wake and run occasionally, even if there is no job scheduled, by [adding a cron event to your crontab file](#adding-cron-to-your-crontab-file).

As LiveCode is single-threaded, CRON will only be able to launch a single job at a time.
It will check the `waitDepth` to make sure no other tasks or handlers are pending or in process before launching a job.



## CAUTION

**CAPRICIOUS CRONJOBS CAN CAUSE CALAMITOUS CATASTROPHES, K?**
Cronjobs can be added, modified, or deleted by anyone who can modify your crontab file, even after your app is signed, built, approved, and distributed.
**CRON does not attempt to limit or control the scheduling of arbitrary code.
CRON will execute whatever commands are in the crontab file.
CRON can be used to sideload code.**
This allows you as a developer to debug your app on the fly, patch it, add or disable features, or write and execute additional code, including adding frontscripts and backscripts.
**IT CAN THEREFORE BE DANGEROUS** as anyone who can edit the crontab file can abuse it to add arbitrary code and get your app to execute that code.
It is possible for CRON to be abused to insert keyloggers, popovers, or other malware.  It can also be accidentally abused to modify or delete files, databases, 
You should ensure that your crontab file cannot be modified by any untrusted person or user of your app.



## Installation

Whether submoduling or just installing the library, the path to use is `app/libraries/cron`



## Initializing

The library will auto-initialize with any other libraries in your `app/libraries` directory



## app.yml parameters

To pre-configure CRON with your `app.yml` file.
1. First, add a `cron` section
2. Next, any of the following subkeys can be assigned (all are optional).

|  Type  |  Description  | Default |
|------------|---------------|--|
| `retrySeconds` | How long to wait to see if it's ok to launch a job in seconds if another job is already running| 60 |
| `source` | What the cron data will pull from. Current options are: `file` and `manual` | file |
| `path` | Path to the `crontab.txt` file relative to `app.yml` | ./assets/crontab.txt) |
| `logType` | The type/label CRON will use when logging messages | cron |


### Example:
```
#app.yml

cron:
   retrySeconds: 30
   source: file
   path: ~/someRandomFolder/my_cronjobs.txt
   logType: developer
```



## Crontab File Format

By default, CRON will assume that its tasks are located in the `./assets/crontab.txt` file.  You can override that setting in the `app.yml` file.
The file is pipe ("|")/linefeed delimited (pipe/carriage-return on windows)
*"Column" names below do not have special meaning.*
Columns are:

Column | Type | Optional | Description
--|--|--|--
| Enabled | Text | Optional | If the column is not empty, the job is enabled.  If the column is empty, the job is disabled. |
| Event Name | Text | Mandatory | Name of the job - must be unique. |
| Priority | Numeric | Optional | Value used to sort jobs when multiple jobs are ready to be launched.  Priority does not have to be unique. |
| Launch After | DateItems | Mandatory | The earliest the job should next launch.  DateItems are used as they are easier to read and manually write than some other date/time formats, such as seconds.  The dateItems format is year,month,day,hour,minute,second,dayOfTheWeek (but dayOfTheWeek is for informational purposes only, and has no effect on anything).  Timezone is assumed to be local.  |
| Action | Text | Mandatory | LiveCode command CRON should execute |
| Next Run | Real | Optional | Number of seconds after previous run achieves before job should launch again, or blank if it should never run again. |
| Group | Text | Optional | Used to categorize jobs so they can be cancelled en-masse (useful with card-related jobs, for example ) |
| Comment | Text | Optional | The rest of the line is ignored and may be used for comments. |

### Example:
```
X | pinger | |2019,5,21,22,38,26,3 | put "heartbeat" | 60	#I included the "#" just to make the comment easier to spot, but it is unnecessary.
:-) | test | 1 | 2019,05,22,08,00,00,4 | sendEmail| 38400 |					DateItems are year,month,day,hour,minute,second,dayOfTheWeek (but dayOfWeek doesn't do anything, so don't worry about setting it)
Enabled	|	hello|1|2019,05,22,08,00,00,4|someScriptToCall|3600|In this case, we will have a tie since the priority and launch-after times are the same, so CRON will choose the order.
Yep   |smile|	42 | 2019,05,21,23,00,00,3 |	put "smile"	|300	|Notice that you can also use strings in your priority/sort order
	| boomies ||		2018,07,04,22,00,00,0 |	send "lightFuse" to button "Launch Fireworks" of card "Independence Day" of stack "Celebration"	|0|	Since the first column is empty, this job is disabled.
```



## Adding CRON to your crontab file

If for whatever reason you want to supplement CRON's scheduling so that it runs periodically whether it thinks it needs to or not, you can add the following line to your crontab file (for example):
```
X	| Extra CRON |	1 |	1969,12,31,19,0,0,4 |	cron	| 3600|	Makes CRON run hourly whether it needs to or not
```
This will not stop CRON from launching when it thinks it has a job to do, it will simply ensure that it also runs at whatever interval you set.

*Discussion:*
* Anything but empty in the first item enables the job.
* I called my job "Extra CRON", just because.  There is no reason why you can't just call it "cron", if you wish.
* The priority is optional, so I left it alone.  You could make it 999999, etc. to give it a lower priority than your other jobs if you wish.
* The "Run After DateItems" column is just some time in the past so my Extra CRON job gets into the schedule.
* "cron" is the command being called
* 3600 seconds is one hour.
* The rest is comment.



## Logging

CRON uses the Levure logging functions.  It will post messages using the `cron` log type by default, although you can override that in the `app.yml` file.
CRON will log everything that it does, from starting, to the job it is going to execute, to the job achieving, to the upcoming schedule.

To activate logging for CRON, add
`
loggerAddType "cron"
`
in your code.

To stop logging for CRON, add
`
loggerRemoveType "cron"
`



## Public API

 ### cron
 Synonym of [CRONStart](#CRONStart)
That's it.  Call `cron`.  It loads cronjobs from the crontab table and fires them off as needed.

You can also manually invoke `cron` at any time to force it to re-read your crontab file and reschedule jobs.  Otherwise, CRON will sleep until what it thinks is its next-scheduled job.

You can also schedule CRON to run regularly, even if no other job is scheduled to run, by [adding cron to your crontab file](#adding-cron-to-your-crontab-file).



### CRONAddJob eventName , { priority } , firstRunInNSeconds , action , recurring { , groupName }
Adds the job to the list
Parameters:
ParameterName | Type | Optional | Description
--|--|--|--
eventName | text | Mandatory | Name of the job
priority | text | Optional | To break ties, **CRON** sorts by priority, so it can be anything
firstRunInNSeconds | real | Mandatory | How long from now to execute the event the first time 
action | text | Mandatory | Command you want to have **CRON** run
runEveryNSeconds | integer | optional | How often to repeat (if repeating) 
groupName | text | optional | Makes it easier to mass-cancel jobs, e.g. jobs for a card.



### function CRONDebug

Returns the cron schedule, in the internal format



### CRONDropJob eventName

Name of the job to drop

  

### CRONCancelGroup groupName

Cancels all pending jobs in group *groupName*

  

### CRONStart

Synonym for [CRON](#CRON)



### CRONStop

Stops CRON



## Private API

### _CRON

  Does the work



### Function _readCrontab ( [convertToSecondsBool [ , trimColumnsBool ] ] ) -> text

Returns the crontab data, either by reading it from the crontab file (if the **source** attribute in the **app.yml** file is *file*) or just by returing the variable if it is not.

* If **convertToSecondsBool** then the **launchAfter** field is converted from dateItems to seconds
* If **trimColumnsBool** then excess spaces on the front and back of the columns are trimmed.



### Function _timeStamp () -> text

Returns a string with the short date and short time



### Function _longDateItems () ->text

Returns the **dateItems** with each field at max length (YYYY,MM,DD,HH,MM,SS,D)



### _cancelTask taskName

Cancels the task in the pendingMessages with the name *taskName*



### _scheduleCron inNumberOfSeconds : longint

Schedules CRON to run for the EARLIER of the next time it's already scheduled (if it's already scheduled) or inNumberOfSeconds.



### Function _trim ( pWhat [ , pOpt_Position ] ) -> text

From Ken Ray, sdtlib 1.0b

Removes white space (spaces, tabs, linefeeds, hard spaces, and returns) from the beginning and end of a container, or optionally only from the beginning (pass "left" or "begin") or end of a container (pass "right" or "end")