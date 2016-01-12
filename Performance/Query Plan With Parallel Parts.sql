WITH XMLNAMESPACES 
   (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')    

, handles AS (
    SELECT  cp.plan_handle, 
            CAST(qp.query_plan AS XML) AS query_plan, 
            usecounts
    FROM sys.dm_exec_cached_plans AS cp 
    CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp 
)
SELECT 
    DENSE_RANK() OVER (ORDER BY handles.plan_handle) Q_RN,
    ROW_NUMBER() OVER (PARTITION BY handles.plan_handle ORDER BY (select NULL)) Op_RN,
    logicalOP.value('(@PhysicalOp)[1]', 'varchar(100)') AS physicalOp,
    logicalOP.value('(@EstimateRows)[1]', 'varchar(100)') AS EstimateRows,


    logicalOP.value('(./IndexScan/Object/@Table)[1]', 'varchar(100)') AS op_on_table,
    logicalOP.value('(./IndexScan/Object/@Index)[1]', 'varchar(100)') AS op_on_index,
    logicalOP.value('(./IndexScan/Object/@IndexKind)[1]', 'varchar(100)') AS op_idx_kind,
    logicalOP.value('(./IndexScan/@Ordered)[1]', 'int') AS op_Ordered,
    logicalOP.value('(./IndexScan/@ScanDirection)[1]', 'varchar(1)') AS op_ScanDirection,

    REPLACE(logicalOP.query(' 
            for $column in IndexScan/DefinedValues/DefinedValue/ColumnReference 
            return string($column/@Column) 
            ').value('.', 'varchar(max)'), ' ', ', ') AS [op_ref_columns] , 

    logicalOP.value('(./IndexScan/Object/@Database)[1]', 'varchar(100)') AS op_Database,
    logicalOP.value('(./IndexScan/Object/@Schema)[1]', 'varchar(100)') AS op_Schema,

    logicalOP.value('(@EstimateRows)[1]', 'varchar(100)') AS EstimateRows,
    logicalOP.value('(@EstimateIO)[1]', 'varchar(100)') AS EstimateIO,
    logicalOP.value('(@EstimateCPU)[1]', 'varchar(100)') AS EstimateCPU,
    logicalOP.value('(@AvgRowSize)[1]', 'varchar(100)') AS AvgRowSize,
    logicalOP.value('(@EstimatedTotalSubtreeCost)[1]', 'varchar(100)') AS EstimatedTotalSubtreeCost,
    logicalOP.value('(@TableCardinality)[1]', 'varchar(100)') AS TableCardinality,
    logicalOP.value('(@Parallel)[1]', 'varchar(100)') AS Parallel,
    logicalOP.value('(@EstimateRebinds)[1]', 'varchar(100)') AS EstimateRebinds,
    logicalOP.value('(@EstimateRewinds)[1]', 'varchar(100)') AS EstimateRewinds,
    logicalOP.value('(@EstimatedExecutionMode)[1]', 'varchar(100)') AS EstimatedExecutionMode,

    stmt.value('(@CardinalityEstimationModelVersion)[1]', 'varchar(100)') AS CE_Version,

    --seekPredicates.value('(./SeekPredicateNew/SeekKeys/Prefix/@ScanType)[1]', 'varchar(max)') AS seek_type,
    --scanPredicates.value('(./IndexScan/Object/@Schema)[1]', 'varchar(max)') AS op_Schema,
	stmt.value('(@StatementText)[1]', 'varchar(max)') AS SQL_Text, 
	usecounts as [Use Count], 
	plan_handle, 
	query_plan
FROM handles
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS batch(stmt) 
--CROSS APPLY stmt.nodes('.//IndexScan/Object[@Index=sql:variable("@IndexName")]') AS idx(obj) 
OUTER APPLY stmt.nodes('.//RelOp') as logicalOps(logicalOP)
--OUTER APPLY logicalOP.nodes('.//SeekPredicates') as seekPred(seekPredicates)
--OUTER APPLY logicalOP.nodes('.//Predicate') as scanPred(scanPredicates)
WHERE  
    stmt.value('declare namespace p="http://schemas.microsoft.com/sqlserver/2004/07/showplan";
max(//p:RelOp/@Parallel)', 'float') > 0
OPTION(MAXDOP 1, RECOMPILE);