USE [PAT_CENITEX_PROD]
GO

/****** Object:  StoredProcedure [dbo].[usp_PAT_Port_Refresh]    Script Date: 18/11/2016 5:08:05 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		tt13
-- Create date: 01/06/2015
-- Description:	port refresh
-- =============================================
CREATE PROCEDURE [dbo].[usp_PAT_Port_Refresh]
	-- Add the parameters for the stored procedure here
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    /*----------------------------------------STAGE 0----------------------------------------*/
	
	drop table dbo.tbl_PAT_Port

	/*----------------------------------------STAGE 1----------------------------------------*/
	SELECT

	/*The following fields are native from PAT project table (with minor tweaks on formatting)*/
	------------------------------------------Start------------------------------------------
	subprogramme,
	isnull(citowner, 'No Primary Owner') [Primary Owner], 
	substring(citowner_1, 4, CHARINDEX('/', CITOwner_1)-4) [Secondary Owner], 
	case when boowner like 'CN=%' then substring(boowner, 4, CHARINDEX('/', boowner)-4)
	else boowner
	end [Customer PM], 
	case when BContact like 'CN=%' then substring(BContact, 4, CHARINDEX('/', BContact)-4)
	else BContact
	end [Customer Executive], 
	status [Status], 
	SourceBusiness [Department], 
	patid [PAT Code], 
	project [Project Activity], 
	programme [Portfolio], 
	PlanEndDate [Planned End Date], 
	IRevStartDate [Baseline Start Date],
	RevEndDate [Baseline End Date], 
	PercentComplete [%Complete], 
	convert(datetime, right(substring(DocHistory,0,11),4) + substring(dochistory,4,2) + left(substring(docHistory,0,9),2),101) as [Last updated], 
	ProjectStatusDesc [Commentary for Internal Stakeholders], 
	Comments [Commentary for External Stakeholders], 
	pj.CurrentPAAmount [Budget], 
	cast(pj.pa1committedong as float) [Ongoing Cost],
	BaseLabour1 [Baseline Labour],
	BaseHW1 [Baseline Hardware],
	BaseSW1 [Baseline Software],
	BaseMisc1 [Baseline Misc],
	-------------------------------------------End-------------------------------------------

	/*
	The fields below are made up to prepare for the calculations in STAGE 2;
	"Write-Off" is currently unused however it may be required in the future.
	*/
	------------------------------------------Start------------------------------------------
	cast(0 as float) [Write-Off], 
	cast(0 as float) [Remaining], 
	cast(0 as float) [Perc Budget], 
	'Green' [Health Calculated], 
	'Green' [Schedule Health], 
	'Green' [Budget Health],
	'Green' [Labour Budget Health],
	'Green' [Baseline HSM Health],
	-------------------------------------------End-------------------------------------------

	/*
	Functions to calculate labour cost, committed funds, consumed funds, %schedule, project variation count;
	These calculations can be time-consuming for big projects.
	*/
	------------------------------------------Start------------------------------------------
	dbo.fn_PAT_TotalLabourCost(pj.patid) [Labour], 
	dbo.fn_OraclePO(substring(pj.patid, 3, 6)) [Committed], 
	dbo.fn_OracleTXN(substring(pj.patid, 3, 6)) [Consumed], 
	(cast(datediff(dd, dbo.fn_PAT_FirstStartDate(pj.patid), getdate()) as float) / datediff(dd, dbo.fn_PAT_FirstStartDate(pj.patid), pj.revenddate)) [%Schedule],
	dbo.fn_PAT_VariationCount(pj.PATid) [Variation]
	-------------------------------------------End-------------------------------------------

	INTO dbo.tbl_PAT_Port
	FROM project pj
	WHERE pj.status in ('Delivery Held','Open', 'pending closure', 'approved for delivery') and pj.PATId not like 'XX%'
	ORDER BY citowner, status, SourceBusiness

	/*----------------------------------------STAGE 2----------------------------------------*/
	------------------------------------------Start------------------------------------------
	update dbo.tbl_PAT_Port set [Remaining] = (cast([Budget] as float) - [Consumed] - [Labour] - [Committed])
	update dbo.tbl_PAT_Port set [Perc Budget] = (([Labour] + [Consumed] + [Committed]) / nullif((cast([Budget] as float)),0))
	update dbo.tbl_PAT_Port set [Schedule Health] =
		case when datediff(dd, dbo.fn_PAT_LatestPAEndDate([PAT Code]), getdate()) > 0 then 'Red'
		when ([Planned End Date] > [Baseline End Date] or ([%Schedule]*100 - [%Complete] >= 20))  then 'Amber'
		else 'Green'
		end
	update dbo.tbl_PAT_Port set [Budget Health] = 
		case 
		when [Remaining] < 0 then 'Red'
		when ([Perc Budget] - cast([%Complete]*0.01 as float)) >= 0.2 then 'Amber'
		else 'Green'
		end
	update dbo.tbl_PAT_Port set [Health Calculated] =
		case 
		when ([Schedule Health] = 'Amber' and [Budget Health] = 'Amber') then 'Red'
		when ([Schedule Health] = 'Red' or [Budget Health] = 'Red') then 'Red'
		when ([Schedule Health] = 'Amber' or [Budget Health] = 'Amber') then 'Amber'
		else 'Green'
		end
	update dbo.tbl_PAT_Port set [Labour Budget Health] =
		case
		when ([Labour] > [Baseline Labour]) then 'Red'
		when (([Labour] / nullif((cast([Baseline Labour] as float)),0))*100 - [%Complete] > 20) then 'Amber'
		else 'Green'
		end
	update dbo.tbl_PAT_Port set [Baseline HSM Health] =
		case
		when ([Consumed] + [Committed] > [Baseline Hardware] + [Baseline Software] + [Baseline Misc]) then 'Red'
		when (([Consumed] + [Committed] / nullif((cast(([Baseline Hardware] + [Baseline Software] + [Baseline Misc]) as float)),0))*100 - [%Complete] > 20) then 'Amber'
		else 'Green'
		end
	-------------------------------------------End-------------------------------------------
END

GO

