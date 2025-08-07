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

        // Validate employeeId is not empty
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
                    this.processPositionData(_HcmWorker, employeeId);
                    this.processCompensationData(_IPA_HRIS_Compensation_Table, employeeId);
                }
            }
        }
    }

    private void processPositionData(HcmWorker _HcmWorker, str employeeId)
    {
        HcmPositionDetail _HcmPositionDetail;
        HcmPositionWorkerAssignment _PositionWorkerAssignment;
        HcmPositionRecId primaryPositionRecId;
        int yearDiff, monthDiff, totalMonths;
        str _status;

        while select validtimestate(dateNull(), dateMax()) * from _PositionWorkerAssignment
            where _PositionWorkerAssignment.Worker == _HcmWorker.RecId
        {
            _PositionTable.clear();
            _PositionTable.Employee = employeeId;
            _PositionTable.WorkerRecID = _PositionWorkerAssignment.Worker;
            _PositionTable.PositionValidFrom = _PositionWorkerAssignment.ValidFrom;
            _PositionTable.PositionValidTo = _PositionWorkerAssignment.ValidTo;

            primaryPositionRecId = HcmWorkerHelper::getPrimaryPosition(_PositionWorkerAssignment.Worker);
            _status = (_PositionWorkerAssignment.Position == primaryPositionRecId) ? "Active" : "Past";
            _PositionTable.PositionStatus = _status;

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
            _PositionTable.PositionMonths = totalMonths;

            select firstonly _HcmPositionDetail where _HcmPositionDetail.Position == _PositionWorkerAssignment.Position;
            _PositionTable.PositionTitle = _HcmPositionDetail.Description;

            ttsbegin;
            _PositionTable.insert();
            ttscommit;
       }
    }

    private void processCompensationData(IPA_HRIS_Compensation_Table compTable, str employeeId)
    {
        int numMonth = mthOfYr(compTable.StartDate);
        int numYear = year(compTable.StartDate);
        str fiscalYear = (numMonth >= 7) ? strFmt("%1-%2", numYear, numYear + 1) : strFmt("%1-%2", numYear - 1, numYear);

        IPA_HRIS_Compensation_TempTable tmpUpdate;
        select firstonly forupdate tmpUpdate where tmpUpdate.FiscalYear == fiscalYear && tmpUpdate.Employee == employeeId;

        if (tmpUpdate.RecId)
        {
            // Only update the selected buffer!
            ttsbegin;
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

            // Replace fields
            tmpUpdate.BaseOffice                 = compTable.BaseOffice;
            tmpUpdate.BusinessUnit               = compTable.BusinessUnit;
            tmpUpdate.Territory                  = compTable.Territory;
            tmpUpdate.Project                    = compTable.Project;
            tmpUpdate.CostCenter                 = compTable.CostCenter;
            tmpUpdate.SubDepartment              = compTable.SubDepartment;
            tmpUpdate.ReportingToEmployee        = compTable.ReportingToEmployee;
            tmpUpdate.EndDate                    = compTable.EndDate;

            tmpUpdate.update();
            ttscommit;
        }
        else
        {
            // Only use class-level buffer for insert, and always clear before use
            ttsbegin;
            compensationTmp.clear();
            
            // CRITICAL FIX: Set the Employee field first - this was missing!
            compensationTmp.Employee                     = employeeId;
            compensationTmp.StartDate                    = compTable.StartDate;
            compensationTmp.EndDate                      = compTable.EndDate;
            compensationTmp.Bonus                        = compTable.Bonus;
            compensationTmp.Comission                    = compTable.Comission;
            compensationTmp.Compuls_Health_insuCont      = compTable.Compuls_Health_insuCont;
            compensationTmp.EducationAllowance           = compTable.EducationAllowance;
            compensationTmp.EOBI                         = compTable.EOBI;
            compensationTmp.FemaleTransport              = compTable.FemaleTransport;
            compensationTmp.GOSI                         = compTable.GOSI;
            compensationTmp.GrossSalary                  = compTable.GrossSalary;
            compensationTmp.IPD                          = compTable.IPD;
            compensationTmp.JobEnhanceAdder              = compTable.JobEnhanceAdder;
            compensationTmp.Mandatory_pension_cont       = compTable.Mandatory_pension_cont;
            compensationTmp.MobileBilling                = compTable.MobileBilling;
            compensationTmp.OPD                          = compTable.OPD;
            compensationTmp.OtherAllowances              = compTable.OtherAllowances;
            compensationTmp.OverTime                     = compTable.OverTime;
            compensationTmp.Pension                      = compTable.Pension;
            compensationTmp.ProjectBonus                 = compTable.ProjectBonus;
            compensationTmp.ProvidentFund                = compTable.ProvidentFund;
            compensationTmp.SalaryAdder                  = compTable.SalaryAdder;
            compensationTmp.SiteAllowance                = compTable.SiteAllowance;
            compensationTmp.TravelTickets                = compTable.TravelTickets;
            compensationTmp.Grand_Total_Monthly          = compTable.Grand_Total_Monthly;
            compensationTmp.GrandTotal_USD_Monthly       = compTable.GrandTotal_USD_Monthly;
            compensationTmp.GrandTotal_USD_Annually      = compTable.GrandTotal_USD_Annually;

            compensationTmp.CurrencyCode                 = compTable.CurrencyCode;
            compensationTmp.BaseOffice                   = compTable.BaseOffice;
            compensationTmp.BusinessUnit                 = compTable.BusinessUnit;
            compensationTmp.Territory                    = compTable.Territory;
            compensationTmp.Project                      = compTable.Project;
            compensationTmp.CostCenter                   = compTable.CostCenter;
            compensationTmp.SubDepartment                = compTable.SubDepartment;
            compensationTmp.ReportingToEmployee          = compTable.ReportingToEmployee;
            compensationTmp.FiscalYear                   = fiscalYear;

            // Validate all required fields before insert
            if (!compensationTmp.Employee)
            {
                throw error("Employee field cannot be empty when inserting compensation data");
            }

            compensationTmp.insert();
            ttscommit;
        }
    }
}