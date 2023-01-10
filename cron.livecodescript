script "cron"

#<don't pre-assign values here b/c each launch of CRON will overwrite existing values set in the libraryStack handler>
   local retrySeconds
   local crontab
   local logType
   local cronSource
   local CRONStop
   local crontabData
   local logBool

   constant defaultRetrySeconds=60
   constant defaultCrontab="./assets/crontab.txt"
   constant defaultLogType="cron"
   constant defaultSource="file"
   constant defaultLogBool=true

   constant colDelim="|" #and maybe it will change some day if we add a parameter...
#</don't pre-assign values here b/c each launch of CRON will overwrite existing values set in the libraryStack handler>


#<crontab columns to use>
   constant enabledCol=1
   constant nameCol=2
   constant priorityCol=3
   constant launchAfterCol=4
   constant actionCol=5
   constant nextRunInNSecondsCol=6
   constant groupCol=7
   constant commentsCol=-1
#</crontab columns to use>

on libraryStack
   if the target is not me then pass libraryStack

   put defaultretrySeconds into retrySeconds
   if levureAppHasProperty ( "cron>retrySeconds" ) then put levureAppGet ( "cron>retrySeconds" ) into retrySeconds

   put defaultSource into cronSource
   if levureAppHasProperty ( "cron>source" ) then put levureAppGet ( "cron>source" ) into cronSource

   if cronSource is "file" then
      put defaultCrontab into crontab
      if levureAppHasProperty ( "cron>path" ) then put levureAppGet ( "cron>path" ) into crontab 
      if char 1 of crontab is "." then  put levureAppFolder() & slash before crontab #add the rest of the path
   end if #cronSource is "file"

   put defaultLogType into logType
   if levureAppHasProperty ( "cron>logType" ) then put levureAppGet ( "cron>logType" ) into logType

   put defaultLogBool into logBool
   if levureAppHasProperty ( "cron>log" ) then put levureAppGet ( "cron>log" ) into logBool
end libraryStack



on releaseStack
   if the target is not me then pass releaseStack
   if logBool then
      loggerLogMsg "CRON released, shutting down." , logType
   end if
end releaseStack



on CRON 
   CRONStart
end CRON



on CRONAddJob eventName , priority , firstRunInNSeconds , action , runEveryNSeconds , groupName
   put firstRunInNSeconds + the seconds into nextLaunch
   
   CRONDropJob eventName // there can be only one

   if crontabData is not empty and last char of crontabData is not cr then
      put cr after crontabData
   end if #crontabData is not empty and last char of crontabData is not cr 

   put "X" & colDelim & eventName & colDelim & priority & colDelim & nextLaunch & colDelim & action & colDelim & runEveryNSeconds & colDelim & groupName after crontabData

   _scheduleCron firstRunInNSeconds
end CRONAddJob



on CRONCancelGroup groupName
   set the itemDelimiter to colDelim
   put empty into newCrontabData
   repeat for each line theLine in crontabData
      if _trim ( item groupCol of theLine ) is not _trim ( groupName ) then
         put theLine & cr after newCrontabData
      end if#item groupCol of theLine is not groupName 
   end repeat#or each line theLine in crontabData
   put newCrontabData into crontabData
end CRONCancelGroup



on CRONDropJob jobName
   set the itemDelimiter to colDelim
   put empty into newCrontabData
   repeat for each line theLine in crontabData
      if _trim ( item nameCol of theLine ) is not _trim ( jobName ) then
         put theLine & cr after newCrontabData
      end if //tem nameCol of theLine is not jobName
   end repeat //for each line theLine in crontabData
   put newCrontabData into crontabData
end CRONDropJob



on CRONStop
   put true into CRONStop
   _CRON
end CRONStop



on CRONStart
   put false into CRONStop
   _CRON
end cronStart


function cronDebug
   return crontabData
end cronDebug


// =============================================================================================================================================================
-->private

private command  _CRON  #manages jobs per the entries in the CRONTAB table in the db
   _cancelTask "CRON" #any other scheduled CRON events
   if CRONStop then
      exit _CRON
   end if #cronstop

   if logBool then
      loggerLogMsg "CRON is starting" , logType
   end if #logBool

   if the waitDepth > 1 then
      if logBool then
         loggerLogMsg "Something is waiting.  CRON will try again in" && retrySeconds && "seconds." , logtype
      end if #logBool
      _scheduleCron retrySeconds
      exit to top
   end if #the waitDepth>1

   put _readCrontab() into crontabData
   if crontabData is empty then
      exit _CRON # by design.  In manual mode, adding a job starts CRON. In file mode, User can always re-invoke it after crontabData is populated, or they can install CRON as a job in crontab.txt
   end if #crontabData is empty

   set the itemDelimiter to colDelim

   put the seconds into theSeconds

   #<find jobs that can run now>
      sort lines of crontabData by item launchAfterCol of each #don't sort by priority yet b/c we first want every job that can run now.
      repeat for each line cronjob in crontabData
         if item enabledCol of cronjob is empty then next repeat #skip disabled
         put item launchAfterCol of cronjob into launchTime
         convert launchTime to seconds
         if launchTime <= theSeconds then put cronjob & cr after cronjobs #this job can run now
      end repeat #for each line cronjob in crontabData
   #</find jobs that can run now>


   if cronjobs is not empty then #have at least one job that can run
      sort cronjobs ascending numeric by item priorityCol of each #Prioritze jobs that can run now.  Sort is stable, so oldest highest priority jobs go first.
      put line 1 of cronjobs into cronjob #the job we're going to run

      _scheduleCron retrySeconds #schedule CRON, again.  Do this first in case something happens, and because LC is single-threaded.

      put item nameCol of cronjob into eventName

      if logBool then
         loggerLogMsg "Starting" && eventName & "." , logtype
      end if #logBool
      put item actionCol of cronjob into action
      try
         send action to the current card of the topStack #do action #all that to finally do something.
      end try
      put the result into theResult
      if theResult is not empty then
         if logBool then
            loggerLogMsg theResult,logType
         end if #logBool
      end if #the result is not empty

      #<if we get here, assume success>
         #<compute next time event will run>
            put item nextRunInNSecondsCol of cronjob into runEveryNSeconds
            if runEveryNSeconds + 0 = 0 then // either empty or 0, don't schedule, again
               put empty into nextScheduledDateItems
               if logBool then
                  loggerLogMsg eventName && "seems to have achieved, and is not scheduled, again." && nextScheduledDateTimeString , logtype
               end if #logBool
            else #schedule
               put the seconds + runEveryNSeconds into nextScheduledSeconds
               put _timestamp ( nextScheduledSeconds ) into nextScheduledDateTimeString 
               if logBool then
                  loggerLogMsg eventName && "seems to have achieved.  Marking and scheduling next run for" && nextScheduledDateTimeString , logtype
               end if #logBool
               put _longDateItems ( nextScheduledSeconds ) into nextScheduledDateItems #make crontab easier to read b/c dateItems can be truncated
            end if #runEveryNSeconds + 0 = 0 
         #</compute next time event will run>

         #<udpate crontab>
            #do it again b/c event may have taken a while
            put _readCrontab ( false , false ) into crontabData #don't trim the column data and don't convert the next launch dateItems to seconds
            put false into found
            put 1 into lineCounter
            put the number of lines in crontabData into numberOfLines
            repeat with i = 1 to numberOfLines
               if _trim ( item nameCol of line i of crontabData ) is eventName then
                  put true into found
                  if nextScheduledDateItems is empty then // don't schedule, again, in fact, mark as disabled
                     put empty into item enabledCol of line i of crontabData
                  else #schedule
                     put space & nextScheduledDateItems & space into item launchAfterCol of line i of crontabData # add spaces to pad value to make it easier to read
                  end if #nextScheduledDateItems is empty
                  exit repeat
               else #no match
                  #do nothing, just move on
               end if #item nameCol of line i of crontabData is eventName
            end repeat #with i = 1 to numberOfLines

            if cronSource is "file" then
               if found then #only update if the job is still in the file, i.e. the user didn't remove it while we were doing something.
                  open file crontab for write
                  write crontabData to file crontab
                  close file crontab
               end if #found
            end if #cronSource is "file"
         #</udpate crontab>
      #</if we get here, assume success>
      _scheduleCron 1 #fire again in case something else is waiting to run.
   else # Nothing to do, go to sleep.
      #<get next scheduled job info.>
         sort lines of crontabData by item priorityCol of each
         sort lines of crontabData by item launchAfterCol of each
         #<find the next enabled job to schedule>
            put 1 into i
            put false into foundOne
            repeat until foundOne or i > the number of lines in crontabData
               if _trim ( item enabledCol of line i of crontabData ) is not empty then
                  put true into foundOne
               else #empty
                  add 1 to i
               end if #_trim (item enabledCol of line i of crontabData) is not empty
            end repeat #until foundOne or i>the number of lines in crontabData
         #</find the next enabled job to schedule>
         if foundOne then
            put line i of crontabData into nextJob
            put item launchAfterCol of nextJob into nextScheduledSeconds
            convert nextScheduledSeconds to seconds
            put _timestamp ( nextScheduledSeconds ) into nextScheduledDateTimeString

            put item nameCol of nextJob into eventName
            if logBool then
               loggerLogMsg "CRON suspending until" && eventName && ", scheduled at:" && nextScheduledDateTimeString & "." , logType #CRON suspending until whateverTheEventNameIs, scheduled at 14:02:00.
            end if #logbool
            _cancelTask "cron"
            _scheduleCron nextScheduledSeconds - the seconds #wake up for next event
         else #nothing enabled to schedule
            if logBool then
               loggerlogmsg "No CRON jobs enabled.  CRON terminating."
            end if #logBool
         end if #foundOne
      #</get next scheduled job info.>

      #<log upcoming schedule, just because>
         delete line 1 of cronjobs #if it exists
         if cronjobs is not empty then
            put "Scheduled to run ASAP:"&cr into schedule
            repeat for each line cronjob in cronjobs
               put item priorityCol of cronjob into priority
               if priority is empty then put "N/A" into priority
               put "Priority:" && priority & tab after schedule
               put item nameCol of cronjob & cr after schedule
            end repeat #for each line cronjob in cronjobs
            delete last line of schedule #trailing cr
            _scheduleCron 1 #other jobs waiting, so run asap
         else #nothing pending, output regular schedule
            put "Upcoming schedule:" & cr into schedule
            sort lines of crontabData by item priorityCol of each #sort by priority second, next run time first
            sort lines of crontabData by item launchAfterCol of each #sort by priority second, next run time first.
            repeat for each line cronjob in crontabData
               if item 1 of cronjob is empty then next repeat #disabled
               put _timestamp ( item launchAfterCol of cronjob ) & tab after schedule
               put item priorityCol of cronjob into priority
               if priority is empty then put "N/A" into priority
               put "Priority:" && priority & tab after schedule
               put  item nameCol of cronjob & cr after schedule
            end repeat #for each line cronjob in crontabData
            delete last char of schedule #trailing cr
         end if #cronjobs is not empty

         if logBool then
            loggerlogmsg ( schedule ),logType
         end if #logBool
      #</log upcoming schedule, just because>
   end if #it is not empty

   if logBool then
      loggerLogMsg "CRON is done",logType
      loggerLogMsg "--------------------------------------------------",logType
   end if #logBool
end _CRON



private function _readCrontab #[convertToSecondsBool[,trimColumnsBool]]
   if the paramCount>=1 then put param(1) into trimColumns else put true into trimColumns
   if the paramCount>=2 then put param(2) into convertToSeconds else put true into convertToSeconds

   set the itemDelimiter to colDelim

   if cronSource is "file" then
      if there is not a file crontab then return empty
      open file crontab
      read from file crontab until end
      put it into crontabData
      close file crontab
   else #cronSource is not "file"
      #do nothing, in manual mode, crontab is maintained, live
   end if #cronSource is "file"


   if trimColumns or convertToSeconds then # have some more work to do besides just returning the contents of the file
      #<walk crontabData and optionally trim and convert>
         repeat with i = 1 to the number of lines in crontabData
            if convertToSeconds then 
               put _trim ( item launchAfterCol of line i of crontabData ) into item launchAfterCol of line i of crontabData #whitespace breaks CONVERT, so trim
               convert item launchAfterCol of line i of crontabData to seconds
            end if #convertToSeconds

            if trimColumns then
               repeat with j = 1 to the number of items in line i of crontabData
                  put _trim ( item j of line i of crontabData ) into item j of line i of crontabData
               end repeat #for each item theColumn in theLine
            end if #trimColumns

         end repeat #for each line theLine in crontabData
      #</walk crontabData and optionally trim and convert>
   end if #trimColumns or convertToSeconds

   return crontabData
end _readCrontab



private function _timeStamp #generates short date and short time
   if the paramCount>=1 then put param(1) into theSeconds else put the seconds into theSeconds
   convert theSeconds to short date and short time
   return theSeconds
end _timeStamp



private function _longDateItems #instead of dateItems, where an item can be abbreviated (3 instead of 03), this makes everything max-width:  4 digits for first and 2 for the rest
   if the paramCount>=1 then put param(1) into theSeconds else put the seconds into theSeconds
   put theSeconds into theDate
   convert theDate to dateItems
   set the numberFormat to "00"
   repeat with i = 2 to 7 #there are 7 items in a dateItems string: year,month,day,hour,minute,second,day of the week.  The year is always 4 digits
      add 0 to item i of theDate #once we do the math, LC will do the conversion, adding any leading zeroes that are necessary.
   end repeat #with i = 2 to 7
   return theDate
end _longDateItems



private command _cancelTask taskName
   put the pendingMessages into theSchedule
   repeat for each line theLine in theSchedule
      if item 3 of theLine is taskName then cancel item 1 of theLine
   end repeat #for each line theLine in theSchedule
end _cancelTask



private command _scheduleCron inNumberOfSeconds
   # Schedules a CRON run for the EARLIER of the next time it's already scheduled (if it's already scheduled) or inNumberOfSeconds.
   put the pendingMessages into theSchedule
   put false into scheduled
   put inNumberOfSeconds + the Seconds into scheduleInNSeconds
   repeat for each line theLine in theSchedule
      if item 3 of theLine is "cron" then #it's scheduled at least once
         put item 2 of theLine into nextScheduledCRONWake
         if scheduleInNSeconds < nextScheduledCRONWake then #inNumberOfSeconds is sooner, so cancel the scheduled job
            _cancelTask "cron"
         else #existing scheduled event is sooner
            put true into scheduled
         end if # inNumberOfSeconds<item 2 of theLine
      end if #item 3 of theLine is "cron"
   end repeat #for each line theLine in theSchedule

   if not scheduled then send "cron" to me in inNumberOfSeconds seconds
end _scheduleCron



private function _trim pWhat,pOpt_Position
   /* trim Text
   Syntax:
   trim (pWhat,[pOpt_Position])
   
   Examples:
   trim ("   This is a test.  ")  --> "This is a test."
   trim ("   This is a test.  ","end") --"   This is a test."
   
   Description:
   Removes white space (spaces, tabs, linefeeds, hard spaces, and returns) from
   the beginning and end of a container, or optionally only from the beginning
   (pass "left" or "begin") or end of a container (pass "right" or "end")
   
   Source:   
   Ken Ray, sdtlib 1.0b
   trim */
   if the platform is "MacOS" then put numToChar(202) into tHardSpc
	else put numToChar(160) into tHardSpc
	if pOpt_Position="" then put "both" into pOpt_Position
	put (space & tab & cr & linefeed & tHardSpc) into tWhiteSpc
	if pOpt_Position is among the items of "both,left,begin" then
	   repeat
	   	if char 1 of pWhat is not in tWhiteSpc then exit repeat
			else delete char 1 of pWhat
		end repeat
	end if
	if pOpt_Position is among the items of "both,right,end" then
	   repeat
	   	if char -1 of pWhat is not in tWhiteSpc then exit repeat
			else delete char -1 of pWhat
		end repeat
	end if
	return pWhat
end _trim