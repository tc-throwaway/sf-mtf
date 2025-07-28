// TODO: In reality I would probably implement a broader trigger framework to handle
// recursion / more granula flow control based on trigger context / logging etc
// but this is an example specific to the assessment.

public class TriggerControl {
    private static Set<String> bypassedTriggers = new Set<String>();
    @TestVisible private static Set<Id> processedTermChanges = new Set<Id>();
    
    public static void bypass(String triggerName) {
        bypassedTriggers.add(triggerName);
    }
    
    public static void clearBypass(String triggerName) {
        bypassedTriggers.remove(triggerName);
    }
    
    public static boolean isBypassed(String triggerName) {
        return bypassedTriggers.contains(triggerName);
    }
    
    public static boolean hasProcessedTermChange(Id loanId) {
        return processedTermChanges.contains(loanId);
    }
    
    public static void markTermChangeProcessed(Id loanId) {
        processedTermChanges.add(loanId);
    }
}