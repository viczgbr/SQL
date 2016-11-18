WITH CTE (
	activitycode
	,weekstartdate
	,resourcerequested
	,requestedhours
	,percenttimereq
	,taskdetails
	)
AS (
	SELECT t2.activitycode
		,t2.weekstartdate
		,t2.ResourceRequested
		,t2.RequestedHours
		,t2.PercentTimeReq
		, REPLACE(REPLACE(REPLACE('<' + 
		stuff((
				SELECT ',' + taskdetails
				FROM rasdata_weekly t1
				WHERE t1.ActivityCode = t2.activitycode
					AND t1.WeekStartDate = t2.WeekStartDate
					AND t1.ResourceRequested = t2.ResourceRequested
					AND t1.RequestedHours = t2.RequestedHours
					--AND t1.PercentTimeReq = t2.PercentTimeReq
				FOR XML path('')
				), 1, 1, '')
				, '<Expr1>', ''), '</Expr1>', '') , ',', '-') 
				AS Taskdetails
	FROM rasdata_weekly t2
	--where t2.ActivityCode = 'ZZ796049' and t2.ResourceRequested like 'Allen b%'
	GROUP BY t2.ActivityCode
		,t2.WeekStartDate
		,t2.RequestedHours
		,t2.ResourceRequested
		,t2.PercentTimeReq
	)
SELECT rw.Team AS to_workgroup_name
	,CASE 
		WHEN rw.ResourceRequested LIKE '%/%'
			THEN substring(rw.ResourceRequested, 0, charindex('/', rw.ResourceRequested))
		WHEN rw.ResourceRequested LIKE '%,%'
			THEN RIGHT(rw.ResourceRequested, len(rw.resourcerequested) - charindex(' ', rw.ResourceRequested)) + ' ' + substring(rw.ResourceRequested, 0, CHARINDEX(',', rw.resourcerequested))
		END AS to_person_name
	,CONVERT(VARCHAR(19), rw.WeekStartDate, 103) AS assign_start_date
	,DATENAME(month, rw.WeekStartDate) AS AssignStartMonth
	,DATENAME(month, rw.WeekStartDate) + ' ' + DATENAME(year, rw.WeekStartDate) AS AssignStartMonthYear
	,DATENAME(year, rw.WeekStartDate) AS year
	,DATEPART(month, rw.WeekStartDate) AS NumericMonth
	,rw.ActivityName AS service_call_short_description
	,CONVERT(INT, rw.PercentTimeReq) AS assign_perc
	,rw.BookingType
	,rw.RequestedHours
	,rw.ResourceRequested
	,TaskTable.Taskdetails
FROM dbo.RASData_Weekly rw
INNER JOIN CTE AS TaskTable ON rw.ActivityCode = TaskTable.ActivityCode
	AND rw.WeekStartDate = TaskTable.WeekStartDate
	AND rw.ResourceRequested = TaskTable.ResourceRequested
	AND rw.RequestedHours = tasktable.RequestedHours
	AND rw.PercentTimeReq = TaskTable.PercentTimeReq
WHERE (TaskTable.WeekStartDate >= DATEADD(ww, DATEDIFF(ww, 0, GETDATE()), 0))
	AND (tasktable.WeekStartDate <= DATEADD(ww, DATEDIFF(ww, 0, GETDATE()) + 23, 0))
	AND (rw.STATUS = 'Confirmed')