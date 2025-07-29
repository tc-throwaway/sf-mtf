/**
 * @description Very basic trigger framework to control recursion. In reality you would implement a broader 
 *              trigger framework to handle recursion / more granula flow control based on trigger context / logging etc
 * @author @tomcarman
 * @since Q3 2025
 */

public class TriggerControl {

    /**
     * @description Set of trigger names that are currently being bypassed for this transaction
     */
    private static Set<String> bypassedTriggers = new Set<String>();

    /**
     * @description Set of Term Changes that have already been processed, used by LoanService.cls
     */
    @TestVisible private static Set<Id> processedTermChanges = new Set<Id>();
    
    /**
     * @description Add a trigger to be bypassed in the current transaction
     * @param triggerName The name of the trigger e.g. 'LoanChargeTrigger'
     */
    public static void bypass(String triggerName) {
        bypassedTriggers.add(triggerName);
    }
    
    /**
     * @description Remove a previously added trigger from being bypassed in the current transaction
     * @param triggerName The name of the trigger e.g. 'LoanChargeTrigger'
     */
    public static void clearBypass(String triggerName) {
        bypassedTriggers.remove(triggerName);
    }
    
    /**
     * @description Check if a trigger is currently being bypassed given its name
     * @param triggerName The name of the trigger e.g. 'LoanChargeTrigger'
     * @return  `boolean` Whether the trigger is being bypassed in the current transaction
     */
    public static boolean isBypassed(String triggerName) {
        return bypassedTriggers.contains(triggerName);
    }
    
    /**
     * @description Given a Loan Id, check if it has processed Term Changes in the current transaction
     * @param loanId Id of the Loan to check
     * @return  `boolean` Whether the Loan has had Term Changes processed during this transaction
     */
    public static boolean hasProcessedTermChange(Id loanId) {
        return processedTermChanges.contains(loanId);
    }
    
    /**
     * @description Given a Loan Id, add it to a set that tracks Loans that have had Term Changes processed in the current transaction
     * @param loanId Id of the Loan to add
     */
    public static void markTermChangeProcessed(Id loanId) {
        processedTermChanges.add(loanId);
    }
}