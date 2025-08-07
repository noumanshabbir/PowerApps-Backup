// SOLUTION 2: Separate methods with proper temporary table context management
[SRSReportQueryAttribute(querystr(IPA_HRIS_Compensation_Report_Query)),
 SRSReportParameterAttribute(classStr(HRIS_Compensation_ReportClassContract))]
public class HRIS_Compensation_ReportClassDP extends SrsReportDataProviderPreProcessTempDB
{
    IPA_HRIS_Compensation_TempTable compensationTmp;
    IPA_HRIS_Comp_Report_PositionTmp _PositionTable;
    IPA_HRIS_Compensation_Table _IPA_HRIS_Compensation_Table;
    HcmWorker _HcmWorker;

    [SRSReportDataSetAttribute(tablestr('IPA_HRIS_Compensation_TempTable'))]
    public IPA_HRIS_Compensation_TempTable getTempTable()
    {
        select * from compensationTmp;
        return compensationTmp;
    }

    [SRSReportDataSetAttribute(tablestr('IPA_HRIS_Comp_Report_PositionTmp'))]
    public IPA_HRIS_Comp_Report_PositionTmp getTempTable_Compensation()
    {
        select * from _PositionTable;
        return _PositionTable;
    }

    public void processReport()
    {
        HRIS_Compensation_ReportClassContract contract = this.parmDataContract();
        str employeeId = contract.parmEmployeeId();

        if (!employeeId)
        {
            throw error("Employee ID cannot be empty");
        }

        delete_from compensationTmp;
        delete_from _PositionTable;

        while select * from _IPA_HRIS_Compensation_Table order by _IPA_HRIS_Compensation_Table.StartDate asc
        {
            if (_IPA_HRIS_Compensation_Table.Employee == employeeId)
            {
                select firstonly _HcmWorker where _HcmWorker.PersonnelNumber == employeeId;
                if (_HcmWorker)
                {
                    // Only call position processing once per worker
                    this.processPositionData(_HcmWorker.RecId, employeeId);
                    this.processCompensationData(_IPA_HRIS_Compensation_Table, employeeId);
                }
            }
        }
    }

    private void processPositionData(RecId workerRecId, str employeeId)
    {
        HcmPositionDetail _HcmPositionDetail;
        HcmPositionWorkerAssignment _PositionWorkerAssignment;
        HcmPositionRecId primaryPositionRecId;
        int yearDiff, monthDiff, totalMonths;
        str _status;

        // CRITICAL: Use a single transaction for all position data
        ttsbegin;
        
        while select validtimestate(dateNull(), dateMax()) * from _PositionWorkerAssignment
            where _PositionWorkerAssignment.Worker == workerRecId
        {
            // Use local buffer instead of class-level buffer
            IPA_HRIS_Comp_Report_PositionTmp localPositionTable;
            
            localPositionTable.clear();
            localPositionTable.Employee = employeeId;
            localPositionTable.WorkerRecID = _PositionWorkerAssignment.Worker;
            localPositionTable.PositionValidFrom = _PositionWorkerAssignment.ValidFrom;
            localPositionTable.PositionValidTo = _PositionWorkerAssignment.ValidTo;

            primaryPositionRecId = HcmWorkerHelper::getPrimaryPosition(_PositionWorkerAssignment.Worker);
            _status = (_PositionWorkerAssignment.Position == primaryPositionRecId) ? "Active" : "Past";
            localPositionTable.PositionStatus = _status;

            utcdatetime fromDate = _PositionWorkerAssignment.ValidFrom;
            utcdatetime toDate = _PositionWorkerAssignment.ValidTo;
            if (year(dateTimeUtil::date(toDate)) > 2100)
            {
                toDate = DateTimeUtil::getSystemDateTime();
            }

            TransDate from = dateTimeUtil::date(fromDate);
            TransDate to = dateTimeUtil::date(toDate);
            yearDiff = year(to) - year(from);
            monthDiff = mthOfYr(to) - mthOfYr(from);
            totalMonths = (yearDiff * 12) + monthDiff;
            localPositionTable.PositionMonths = totalMonths;

            select firstonly _HcmPositionDetail where _HcmPositionDetail.Position == _PositionWorkerAssignment.Position;
            localPositionTable.PositionTitle = _HcmPositionDetail.Description;

            // Insert into class buffer for report framework
            _PositionTable.data(localPositionTable);
            _PositionTable.insert();
        }
        
        ttscommit;
    }

    private void processCompensationData(IPA_HRIS_Compensation_Table compTable, str employeeId)
    {
        int numMonth = mthOfYr(compTable.StartDate);
        int numYear = year(compTable.StartDate);
        str fiscalYear = (numMonth >= 7) ? strFmt("%1-%2", numYear, numYear + 1) : strFmt("%1-%2", numYear - 1, numYear);

        // CRITICAL: Use single transaction and proper buffer management
        ttsbegin;
        
        IPA_HRIS_Compensation_TempTable tmpUpdate;
        select firstonly forupdate tmpUpdate where tmpUpdate.FiscalYear == fiscalYear && tmpUpdate.Employee == employeeId;

        if (tmpUpdate.RecId)
        {
            tmpUpdate.Bonus                      += compTable.Bonus;
            tmpUpdate.Comission                  += compTable.Comission;
            tmpUpdate.Compuls_Health_insuCont    += compTable.Compuls_Health_insuCont;
            tmpUpdate.EducationAllowance         += compTable.EducationAllowance;
            tmpUpdate.EOBI                       += compTable.EOBI;
            tmpUpdate.FemaleTransport            += compTable.FemaleTransport;
            tmpUpdate.GOSI                       += compTable.GOSI;
            tmpUpdate.GrossSalary                += compTable.GrossSalary;
            tmpUpdate.IPD                        += compTable.IPD;
            tmpUpdate.JobEnhanceAdder            += compTable.JobEnhanceAdder;
            tmpUpdate.Mandatory_pension_cont     += compTable.Mandatory_pension_cont;
            tmpUpdate.MobileBilling              += compTable.MobileBilling;
            tmpUpdate.OPD                        += compTable.OPD;
            tmpUpdate.OtherAllowances            += compTable.OtherAllowances;
            tmpUpdate.OverTime                   += compTable.OverTime;
            tmpUpdate.Pension                    += compTable.Pension;
            tmpUpdate.ProjectBonus               += compTable.ProjectBonus;
            tmpUpdate.ProvidentFund              += compTable.ProvidentFund;
            tmpUpdate.SalaryAdder                += compTable.SalaryAdder;
            tmpUpdate.SiteAllowance              += compTable.SiteAllowance;
            tmpUpdate.TravelTickets              += compTable.TravelTickets;
            tmpUpdate.Grand_Total_Monthly        += compTable.Grand_Total_Monthly;
            tmpUpdate.GrandTotal_USD_Monthly     += compTable.GrandTotal_USD_Monthly;
            tmpUpdate.GrandTotal_USD_Annually    += compTable.GrandTotal_USD_Annually;

            tmpUpdate.BaseOffice                 = compTable.BaseOffice;
            tmpUpdate.BusinessUnit               = compTable.BusinessUnit;
            tmpUpdate.Territory                  = compTable.Territory;
            tmpUpdate.Project                    = compTable.Project;
            tmpUpdate.CostCenter                 = compTable.CostCenter;
            tmpUpdate.SubDepartment              = compTable.SubDepartment;
            tmpUpdate.ReportingToEmployee        = compTable.ReportingToEmployee;
            tmpUpdate.EndDate                    = compTable.EndDate;

            tmpUpdate.update();
        }
        else
        {
            // Use local buffer and copy to class buffer
            IPA_HRIS_Compensation_TempTable localCompensationTmp;
            
            localCompensationTmp.clear();
            localCompensationTmp.Employee                     = employeeId;
            localCompensationTmp.StartDate                    = compTable.StartDate;
            localCompensationTmp.EndDate                      = compTable.EndDate;
            localCompensationTmp.Bonus                        = compTable.Bonus;
            localCompensationTmp.Comission                    = compTable.Comission;
            localCompensationTmp.Compuls_Health_insuCont      = compTable.Compuls_Health_insuCont;
            localCompensationTmp.EducationAllowance           = compTable.EducationAllowance;
            localCompensationTmp.EOBI                         = compTable.EOBI;
            localCompensationTmp.FemaleTransport              = compTable.FemaleTransport;
            localCompensationTmp.GOSI                         = compTable.GOSI;
            localCompensationTmp.GrossSalary                  = compTable.GrossSalary;
            localCompensationTmp.IPD                          = compTable.IPD;
            localCompensationTmp.JobEnhanceAdder              = compTable.JobEnhanceAdder;
            localCompensationTmp.Mandatory_pension_cont       = compTable.Mandatory_pension_cont;
            localCompensationTmp.MobileBilling                = compTable.MobileBilling;
            localCompensationTmp.OPD                          = compTable.OPD;
            localCompensationTmp.OtherAllowances              = compTable.OtherAllowances;
            localCompensationTmp.OverTime                     = compTable.OverTime;
            localCompensationTmp.Pension                      = compTable.Pension;
            localCompensationTmp.ProjectBonus                 = compTable.ProjectBonus;
            localCompensationTmp.ProvidentFund                = compTable.ProvidentFund;
            localCompensationTmp.SalaryAdder                  = compTable.SalaryAdder;
            localCompensationTmp.SiteAllowance                = compTable.SiteAllowance;
            localCompensationTmp.TravelTickets                = compTable.TravelTickets;
            localCompensationTmp.Grand_Total_Monthly          = compTable.Grand_Total_Monthly;
            localCompensationTmp.GrandTotal_USD_Monthly       = compTable.GrandTotal_USD_Monthly;
            localCompensationTmp.GrandTotal_USD_Annually      = compTable.GrandTotal_USD_Annually;
            localCompensationTmp.CurrencyCode                 = compTable.CurrencyCode;
            localCompensationTmp.BaseOffice                   = compTable.BaseOffice;
            localCompensationTmp.BusinessUnit                 = compTable.BusinessUnit;
            localCompensationTmp.Territory                    = compTable.Territory;
            localCompensationTmp.Project                      = compTable.Project;
            localCompensationTmp.CostCenter                   = compTable.CostCenter;
            localCompensationTmp.SubDepartment                = compTable.SubDepartment;
            localCompensationTmp.ReportingToEmployee          = compTable.ReportingToEmployee;
            localCompensationTmp.FiscalYear                   = fiscalYear;

            // Copy to class buffer for report framework
            compensationTmp.data(localCompensationTmp);
            compensationTmp.insert();
        }
        
        ttscommit;
    }
}