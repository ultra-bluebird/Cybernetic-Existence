# Emergency Cookie & Session Defense Protocol

## Target Scenario
Malicious `__Secure-next-auth.session-token` and `cf_clearance` cookies are preventing login and page access on Perplexity.ai. This protocol isolates and neutralizes the threat.

## Immediate Hard Reset (Terminal Method)
1.  **Purge Local Storage**:
    ```bash
    # Clear all Chromium-based browser data without launching the GUI
    rm -rf ~/.config/google-chrome/Default/Cookies
    rm -rf ~/.config/google-chrome/Default/Local\ Storage/
