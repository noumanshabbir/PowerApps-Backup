// SOLUTION 1: Keep everything in processReport() method (as you mentioned this works)
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
        
        HcmPositionDetail _HcmPositionDetail;
        HcmPositionWorkerAssignment _PositionWorkerAssignment;
        HcmPositionRecId primaryPositionRecId;
        int yearDiff, monthDiff, totalMonths, numMonth, numYear;
        str _status, fiscalYear;
        IPA_HRIS_Compensation_TempTable tmpUpdate;

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
                    // Process Position Data inline
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

                    // Process Compensation Data inline
                    numMonth = mthOfYr(_IPA_HRIS_Compensation_Table.StartDate);
                    numYear = year(_IPA_HRIS_Compensation_Table.StartDate);
                    fiscalYear = (numMonth >= 7) ? strFmt("%1-%2", numYear, numYear + 1) : strFmt("%1-%2", numYear - 1, numYear);

                    select firstonly forupdate tmpUpdate where tmpUpdate.FiscalYear == fiscalYear && tmpUpdate.Employee == employeeId;

                    if (tmpUpdate.RecId)
                    {
                        ttsbegin;
                        tmpUpdate.Bonus                      += _IPA_HRIS_Compensation_Table.Bonus;
                        tmpUpdate.Comission                  += _IPA_HRIS_Compensation_Table.Comission;
                        tmpUpdate.Compuls_Health_insuCont    += _IPA_HRIS_Compensation_Table.Compuls_Health_insuCont;
                        tmpUpdate.EducationAllowance         += _IPA_HRIS_Compensation_Table.EducationAllowance;
                        tmpUpdate.EOBI                       += _IPA_HRIS_Compensation_Table.EOBI;
                        tmpUpdate.FemaleTransport            += _IPA_HRIS_Compensation_Table.FemaleTransport;
                        tmpUpdate.GOSI                       += _IPA_HRIS_Compensation_Table.GOSI;
                        tmpUpdate.GrossSalary                += _IPA_HRIS_Compensation_Table.GrossSalary;
                        tmpUpdate.IPD                        += _IPA_HRIS_Compensation_Table.IPD;
                        tmpUpdate.JobEnhanceAdder            += _IPA_HRIS_Compensation_Table.JobEnhanceAdder;
                        tmpUpdate.Mandatory_pension_cont     += _IPA_HRIS_Compensation_Table.Mandatory_pension_cont;
                        tmpUpdate.MobileBilling              += _IPA_HRIS_Compensation_Table.MobileBilling;
                        tmpUpdate.OPD                        += _IPA_HRIS_Compensation_Table.OPD;
                        tmpUpdate.OtherAllowances            += _IPA_HRIS_Compensation_Table.OtherAllowances;
                        tmpUpdate.OverTime                   += _IPA_HRIS_Compensation_Table.OverTime;
                        tmpUpdate.Pension                    += _IPA_HRIS_Compensation_Table.Pension;
                        tmpUpdate.ProjectBonus               += _IPA_HRIS_Compensation_Table.ProjectBonus;
                        tmpUpdate.ProvidentFund              += _IPA_HRIS_Compensation_Table.ProvidentFund;
                        tmpUpdate.SalaryAdder                += _IPA_HRIS_Compensation_Table.SalaryAdder;
                        tmpUpdate.SiteAllowance              += _IPA_HRIS_Compensation_Table.SiteAllowance;
                        tmpUpdate.TravelTickets              += _IPA_HRIS_Compensation_Table.TravelTickets;
                        tmpUpdate.Grand_Total_Monthly        += _IPA_HRIS_Compensation_Table.Grand_Total_Monthly;
                        tmpUpdate.GrandTotal_USD_Monthly     += _IPA_HRIS_Compensation_Table.GrandTotal_USD_Monthly;
                        tmpUpdate.GrandTotal_USD_Annually    += _IPA_HRIS_Compensation_Table.GrandTotal_USD_Annually;

                        tmpUpdate.BaseOffice                 = _IPA_HRIS_Compensation_Table.BaseOffice;
                        tmpUpdate.BusinessUnit               = _IPA_HRIS_Compensation_Table.BusinessUnit;
                        tmpUpdate.Territory                  = _IPA_HRIS_Compensation_Table.Territory;
                        tmpUpdate.Project                    = _IPA_HRIS_Compensation_Table.Project;
                        tmpUpdate.CostCenter                 = _IPA_HRIS_Compensation_Table.CostCenter;
                        tmpUpdate.SubDepartment              = _IPA_HRIS_Compensation_Table.SubDepartment;
                        tmpUpdate.ReportingToEmployee        = _IPA_HRIS_Compensation_Table.ReportingToEmployee;
                        tmpUpdate.EndDate                    = _IPA_HRIS_Compensation_Table.EndDate;

                        tmpUpdate.update();
                        ttscommit;
                    }
                    else
                    {
                        ttsbegin;
                        compensationTmp.clear();
                        compensationTmp.Employee                     = employeeId;
                        compensationTmp.StartDate                    = _IPA_HRIS_Compensation_Table.StartDate;
                        compensationTmp.EndDate                      = _IPA_HRIS_Compensation_Table.EndDate;
                        compensationTmp.Bonus                        = _IPA_HRIS_Compensation_Table.Bonus;
                        compensationTmp.Comission                    = _IPA_HRIS_Compensation_Table.Comission;
                        compensationTmp.Compuls_Health_insuCont      = _IPA_HRIS_Compensation_Table.Compuls_Health_insuCont;
                        compensationTmp.EducationAllowance           = _IPA_HRIS_Compensation_Table.EducationAllowance;
                        compensationTmp.EOBI                         = _IPA_HRIS_Compensation_Table.EOBI;
                        compensationTmp.FemaleTransport              = _IPA_HRIS_Compensation_Table.FemaleTransport;
                        compensationTmp.GOSI                         = _IPA_HRIS_Compensation_Table.GOSI;
                        compensationTmp.GrossSalary                  = _IPA_HRIS_Compensation_Table.GrossSalary;
                        compensationTmp.IPD                          = _IPA_HRIS_Compensation_Table.IPD;
                        compensationTmp.JobEnhanceAdder              = _IPA_HRIS_Compensation_Table.JobEnhanceAdder;
                        compensationTmp.Mandatory_pension_cont       = _IPA_HRIS_Compensation_Table.Mandatory_pension_cont;
                        compensationTmp.MobileBilling                = _IPA_HRIS_Compensation_Table.MobileBilling;
                        compensationTmp.OPD                          = _IPA_HRIS_Compensation_Table.OPD;
                        compensationTmp.OtherAllowances              = _IPA_HRIS_Compensation_Table.OtherAllowances;
                        compensationTmp.OverTime                     = _IPA_HRIS_Compensation_Table.OverTime;
                        compensationTmp.Pension                      = _IPA_HRIS_Compensation_Table.Pension;
                        compensationTmp.ProjectBonus                 = _IPA_HRIS_Compensation_Table.ProjectBonus;
                        compensationTmp.ProvidentFund                = _IPA_HRIS_Compensation_Table.ProvidentFund;
                        compensationTmp.SalaryAdder                  = _IPA_HRIS_Compensation_Table.SalaryAdder;
                        compensationTmp.SiteAllowance                = _IPA_HRIS_Compensation_Table.SiteAllowance;
                        compensationTmp.TravelTickets                = _IPA_HRIS_Compensation_Table.TravelTickets;
                        compensationTmp.Grand_Total_Monthly          = _IPA_HRIS_Compensation_Table.Grand_Total_Monthly;
                        compensationTmp.GrandTotal_USD_Monthly       = _IPA_HRIS_Compensation_Table.GrandTotal_USD_Monthly;
                        compensationTmp.GrandTotal_USD_Annually      = _IPA_HRIS_Compensation_Table.GrandTotal_USD_Annually;
                        compensationTmp.CurrencyCode                 = _IPA_HRIS_Compensation_Table.CurrencyCode;
                        compensationTmp.BaseOffice                   = _IPA_HRIS_Compensation_Table.BaseOffice;
                        compensationTmp.BusinessUnit                 = _IPA_HRIS_Compensation_Table.BusinessUnit;
                        compensationTmp.Territory                    = _IPA_HRIS_Compensation_Table.Territory;
                        compensationTmp.Project                      = _IPA_HRIS_Compensation_Table.Project;
                        compensationTmp.CostCenter                   = _IPA_HRIS_Compensation_Table.CostCenter;
                        compensationTmp.SubDepartment                = _IPA_HRIS_Compensation_Table.SubDepartment;
                        compensationTmp.ReportingToEmployee          = _IPA_HRIS_Compensation_Table.ReportingToEmployee;
                        compensationTmp.FiscalYear                   = fiscalYear;

                        compensationTmp.insert();
                        ttscommit;
                    }
                }
            }
        }
    }
}