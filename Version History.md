# Mikey's CRON Library Version History



## 2.0.0 06/24/22

* **Priority** is numeric, only
* **Next Run** is optional, i.e. job can run one time.
* Extra field added to the job line: **Group**
  * Optional
  * Position -2 (before the **Comment**)
  * Makes flagging groups of jobs easier, which makes stopping them all easier
  * Used for jobs that are related, e.g. tasks that fire for a specific card
* Extra field added to *app.yml*: **Source**
  * Optional
  * For cases where you aren't going to use a crontab file for jobs, e.g. a REST client that periodically polls the server, but whose tasks are different, depending on the card
  * Values are **file** and **manual**
* Handlers and functions added:
Name | Type | Description
--|--|--
CRONAddJob | Command | Add a job to the list for CRON to handle
CRONCancelGroup | Command | Cancel a group of jobs
CRONDebug | Function | Returns the current schedule so you can debug your code, and CRON
CRONDropJob | Command | Drop a job from the list
CRONStart | Command | Synonym for **CRON** <br>Starts CRON
CRONStop | Command | Stops CRON