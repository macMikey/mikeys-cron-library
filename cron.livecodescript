script "cron"

#<don't pre-assign values here b/c each launch of CRON will overwrite existing values set in the libraryStack handler>
   local retrySeconds
   local crontab
   local logType
   constant defaultRetrySeconds=60
   constant defaultCrontab="./assets/crontab.txt"
   constant defaultLogType="cron"

   constant waitForJobToAchieveSeconds=60 #if a job is running, how long to sleep CRON for before trying to run the next job again
#</don't pre-assign values here b/c each launch of CRON will overwrite existing values set in the libraryStack handler>


#<crontab columns to use>
   constant enabledCol=1
   constant nameCol=2
   constant priorityCol=3
   constant launchAfterCol=4
   constant actionCol=5
   constant nextRunCol=6
   constant commentsCol=-1
#</crontab columns to use>


on libraryStack
   if the target is not me then pass libraryStack

   put defaultretrySeconds into retrySeconds
   if levureAppHasProperty("cron>retry") then put levureAppGet ("cron>retry") into retrySeconds

   put defaultCrontab into crontab
   if levureAppHasProperty("cron>path") then put levureAppGet ("cron>path") into crontab 
   if char 1 of crontab is "." then  put levureAppFolder() & slash before crontab #add the rest of the path

   put defaultLogType into logType
   if levureAppHasProperty("cron>logType") then put levureAppGet ("cron>logType") into logType
end libraryStack



on releaseStack
   if the target is not me then pass releaseStack
   loggerLogMsg "CRON released, shutting down.",logType
end releaseStack



on CRON #manages jobs per the entries in the CRONTAB table in the db
   cancelTask "CRON" #any other scheduled CRON events

   loggerLogMsg "CRON is starting",logType
   if the waitDepth > 1 then
      loggerLogMsg "Something is waiting.  CRON will try again in"&&waitForJobToAchieveSeconds&&"seconds.",logtype
      scheduleCron waitForJobToAchieveSeconds
      exit to top
   end if #the waitDepth>1

   put readCrontab() into crontabData

   set the itemDelimiter to tab


   put the seconds into theSeconds

   #<find jobs that can run now>
      sort lines of crontabData by item launchAfterCol of each #don't sort by priority yet b/c we first want every job that can run now.
      repeat for each line cronjob in crontabData
         if item enabledCol of cronjob is empty then next repeat #skip disabled
         if item launchAfterCol of cronjob<= theSeconds then put cronjob & cr after cronjobs #this job can run now
      end repeat #for each line cronjob in crontabData
   #</find jobs that can run now>


   if cronjobs is not empty then #have at least one job that can run
      sort cronjobs by item priorityCol of each #Prioritze jobs that can run now.  Sort is stable, so oldest highest priority jobs go first.
      put line 1 of cronjobs into cronjob #the job we're going to run

      scheduleCron waitForJobToAchieveSeconds #schedule CRON, again.  Do this first in case something happens, and because LC is single-threaded.

      put item nameCol of cronjob into eventName
      loggerLogMsg "Starting"&&eventName&".",logtype
      put item actionCol of cronjob into action

      do action #all that to finally do something.

      #<if we get here, assume success>
         #<compute next time event will run>
            put item nextRunCol of cronjob into runEveryNSeconds
            put the seconds + runEveryNSeconds into nextScheduledSeconds
            put timestamp(nextScheduledSeconds) into nextScheduledDateTimeString 
            loggerLogMsg eventName&&"seems to have achieved.  Marking and scheduling next run for"&&nextScheduledDateTimeString,logtype
            scheduleCron runEveryNSeconds
            put longDateItems(nextScheduledSeconds) into nextScheduledDateItems #make crontab easier to read b/c dateItems can be truncated
         #</compute next time event will run>

         #<udpate crontab>
            #do it again b/c event may have taken a while
            put readCrontab(false) into crontabData #don't convert the next launch dateItems to seconds
            put false into found
            put 1 into lineCounter
            put the number of lines in crontabData into numberOfLines
            repeat with i = 1 to numberOfLines
               if item nameCol of line i of crontabData is eventName then
                  put true into found
                  put nextScheduledDateItems into item launchAfterCol of line i of crontabData
                  exit repeat
               else #no match
                  #do nothing, just move on
               end if #item nameCol of line i of crontabData is eventName
            end repeat #with i = 1 to numberOfLines

            if found then #only update if the job is still in the file, i.e. the user didn't remove it while we were doing something.
               open file crontab for write
               write crontabData to file crontab
               close file crontab
            end if #found
         #</udpate crontab>
      #</if we get here, assume success>
      # If something else is scheduled to run now, no worries, CRON is scheduled to run again in waitForJobToAchieveSeconds
   else # Nothing to do, go to sleep.
      #<get next scheduled job info.>
         if crontabData is empty then 
            scheduleCron retrySeconds
         else #not empty
            sort lines of crontabData by item launchAfterCol of each
            put line 1 of crontabData into nextJob
            put item launchAfterCol of nextJob into nextScheduledSeconds
            convert nextScheduledSeconds to seconds
            put timestamp(nextScheduledSeconds) into nextScheduledDateTimeString

            put item nameCol of nextJob into eventName
         end if #crontabData is empty
      #</get next scheduled job info.>

      loggerLogMsg "CRON suspending until"&&eventName&&", scheduled at:"&&nextScheduledDateTimeString&".",logType #CRON suspending until whateverTheEventNameIs, scheduled at 14:02:00.
      cancelTask "cron"
      scheduleCron nextScheduledSeconds-the seconds #wake up for next event
   end if #it is not empty

   #<log upcoming schedule, just because>
         delete line 1 of cronjobs #if it exists
         if cronjobs is not empty then
            put "Scheduled to run ASAP:"&cr into schedule
            repeat for each line cronjob in cronjobs
               put item priorityCol of cronjob into priority
               if priority is empty then put "N/A" into priority
               put "Priority:"&&priority & tab after schedule
               put item nameCol of cronjob& cr after schedule
            end repeat #for each line cronjob in cronjobs
            delete last line of schedule #trailing cr
            scheduleCron 1 #other jobs waiting, so run asap
         else #nothing pending, output regular schedule
            put "Upcoming schedule:"&cr into schedule
            sort lines of crontabData by item priorityCol of each #sort by priority second, next run time first
            sort lines of crontabData by item launchAfterCol of each #sort by priority second, next run time first.
            repeat for each line cronjob in crontabData
               if item 1 of cronjob is empty then next repeat #disabled
               put timestamp(item launchAfterCol of cronjob) & tab after schedule
               put item priorityCol of cronjob into priority
               if priority is empty then put "N/A" into priority
               put "Priority:"&&priority & tab after schedule
               put  item nameCol of cronjob & cr after schedule
            end repeat #for each line cronjob in crontabData
            delete last char of schedule #trailing cr
         end if #cronjobs is not empty

         loggerlogmsg(schedule),logType
   #</log upcoming schedule, just because>

   loggerLogMsg "CRON is done",logType
   loggerLogMsg "--------------------------------------------------",logType
end CRON



private function readCrontab
   if the paramCount>=1 then put param(1) into convertToSeconds else put true into convertToSeconds
   set the itemDelimiter to tab
   if there is not a file crontab then return empty
   open file crontab
   read from file crontab until end
   put it into crontabData
   close file crontab
   if convertToSeconds then
      repeat with i = 1 to the number of lines in crontabData
         convert item launchAfterCol of line i of crontabData to seconds
      end repeat #with i = 1 to the number of lines in crontabData
   end if #convertToSeconds
   return crontabData
end readCrontab



private function timeStamp #generates short date and short time
   if the paramCount>=1 then put param(1) into theSeconds else put the seconds into theSeconds
   convert theSeconds to short date and short time
   return theSeconds
end timeStamp



private function longDateItems #instead of dateItems, where an item can be abbreviated (3 instead of 03), this makes everything max-width:  4 digits for first and 2 for the rest
   if the paramCount>=1 then put param(1) into theSeconds else put the seconds into theSeconds
   put theSeconds into theDate
   convert theDate to dateItems
   set the numberFormat to "00"
   repeat with i = 2 to 7 #there are 7 items in a dateItems string: year,month,day,hour,minute,second,day of the week.  The year is always 4 digits
      add 0 to item i of theDate #once we do the math, LC will do the conversion, adding any leading zeroes that are necessary.
   end repeat #with i = 2 to 7
   return theDate
end longDateItems



private command cancelTask taskName
   put the pendingMessages into theSchedule
   repeat for each line theLine in theSchedule
      if item 3 of theLine is taskName then cancel item 1 of theLine
   end repeat #for each line theLine in theSchedule
end cancelTask



private command scheduleCron inNumberOfSeconds
   # Schedules a CRON run for the EARLIER of the next time it's already scheduled (if it's already scheduled) or inNumberOfSeconds.
   put the seconds + inNumberOfSeconds into nextRun
   put the pendingMessages into theSchedule
   put false into scheduled
   repeat for each line theLine in theSchedule
      if item 3 of theLine is "cron" then #it's scheduled at least once
         if inNumberOfSeconds<item 2 of theLine then #inNumberOfSeconds is sooner, so cancel the scheduled job
            cancelTask "cron"
         else #existing scheduled event is sooner
            put true into scheduled
         end if # inNumberOfSeconds<item 2 of theLine
      end if #item 3 of theLine is "cron"
   end repeat #for each line theLine in theSchedule

   if not scheduled then send "cron" to me in inNumberOfSeconds seconds
end scheduleCron