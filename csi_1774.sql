WITH CTE (
	[RowNumber]
	,[Primary Owner]
	,[PAT Code]
	,[MSR or Project]
	,[Vairation Count]
	,[Variation Type]
	,[Variation Add Date]
	,[Variation Finish Date]
	,[PO Number]
	,[Approved Budget]
	,[PAEndDate]
	,[Project]
	,[Baseline PO]
	,[Baseline Finalised Date]
	,[Baseline FY1]
	,[Baseline FY2]
	,[Baseline End Date]
	)
AS (
	SELECT row_number() OVER (
			PARTITION BY pv.[pat code]
			,pv.[primary owner] ORDER BY pv.[pat code]
			) AS [RowNumber]
		,pv.*
		,pj.project
		,pj.PA1PONum [Baseline PO]
		,spe.BaseFinDate [Baseline Finalised Date]
		,pj.BaseFYear1 [Baseline FY1]
		,pj.BaseFYear2 [Baseline FY2]
		,pj.pa1enddate [Baseline End Date]
	FROM vw_rpt_pat_project_var pv
	JOIN project pj ON pv.[PAT Code] = pj.patid
	JOIN SSCPAT_Project2_Export spe ON pj.UniqueID = spe.UniqueID
	)
SELECT a.[RowNumber]
	,a.[Primary Owner]
	,a.[PAT Code]
	,a.[MSR or Project]
	,a.[Vairation Count]
	,a.[Variation Type]
	,a.[Variation Add Date]
	,a.[Variation Finish Date]
	,a.[PO Number]
	,a.[Approved Budget]
	,a.[PAEndDate]
	,case when a.RowNumber = 1 then datediff(dd, a.[Baseline End Date], a.PAEndDate) else datediff(dd, isnull(b.PAEndDate, 0), a.PAEndDate) end [DaysAdded]
	,a.[Project]
	,a.[Baseline PO]
	,a.[Baseline Finalised Date]
	,a.[Baseline FY1]
	,a.[Baseline FY2]
	,a.[Baseline End Date]
FROM CTE a LEFT JOIN CTE b on a.[Primary Owner] = b.[Primary Owner] and a.[PAT Code] = b.[PAT Code] and a.RowNumber = b.RowNumber + 1
order by a.[Primary Owner], a.[PAT Code]