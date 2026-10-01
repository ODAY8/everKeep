$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$device = "emulator-5554"
$jwt = "eyJhbGciOiJFUzI1NiIsImtpZCI6IjYyMzdjMWMyLWE4NDQtNGFjMC05OTkyLWU3OWMwNjJmN2FiYyIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2pheG11cWZvcXZjdGV6bHhiY3RzLnN1cGFiYXNlLmNvL2F1dGgvdjEiLCJzdWIiOiJiYTFhZTYzNS1lMjEzLTQ1NTQtODBmZi1mYjY5NGFhMjU3MDkiLCJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNzkwODg5MDIzLCJpYXQiOjE3OTA4ODU0MjMsImVtYWlsIjoiemFwaXJ5cmVAZ21haWwuY29tIiwicGhvbmUiOiIiLCJhcHBfbWV0YWRhdGEiOnsicHJvdmlkZXIiOiJlbWFpbCIsInByb3ZpZGVycyI6WyJlbWFpbCJdfSwidXNlcl9tZXRhZGF0YSI6eyJlbWFpbCI6InphcGlyeXJlQGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJmdWxsX25hbWUiOiJvZGF5IiwicGhvbmVfdmVyaWZpZWQiOmZhbHNlLCJzdWIiOiJiYTFhZTYzNS1lMjEzLTQ1NTQtODBmZi1mYjY5NGFhMjU3MDkifSwicm9sZSI6ImF1dGhlbnRpY2F0ZWQiLCJhYWwiOiJhYWwxIiwiYW1yIjpbeyJtZXRob2QiOiJwYXNzd29yZCIsInRpbWVzdGFtcCI6MTc5MDg3NjIxOH1dLCJzZXNzaW9uX2lkIjoiODVlMjM0YWYtMjAwNy00NjE3LTkwODEtMzliZTIyNWI1MmJjIiwiaXNfYW5vbnltb3VzIjpmYWxzZX0.EBudh9VJIaJ-CUHv9REnCGXEVil86M167MTVnyIila0FCLTB-HDgsCENGxArKw7hTfPfHunO-0YqK2G38eH9tw"
$headers = @{
    "apikey" = "sb_publishable_xIBiSLeOUtGwC3DQwK820Q_GGpQtkAU"
    "Authorization" = "Bearer $jwt"
}

Write-Output "==> Initializing EverKeep E2E Video QA Session..."

# Clean up any leftover recording
& $adb -s $device shell rm -f /sdcard/everkeep_people_tagging_test.mp4

# Start screenrecord background job
Write-Output "==> Starting Android screen recording on $device (/sdcard/everkeep_people_tagging_test.mp4)..."
$recJob = Start-Job -ScriptBlock {
    param($adbPath, $dev)
    & $adbPath -s $dev shell screenrecord --time-limit 180 /sdcard/everkeep_people_tagging_test.mp4
} -ArgumentList $adb, $device

Start-Sleep -Seconds 2

# TEST 1: Open Memories & Verify Chips
Write-Output "==> [TEST 1] Verifying Memories Screen and People Filter Chips..."
& $adb -s $device exec-out screencap -p > qa/screenshots/step1_memories_screen.png
Start-Sleep -Milliseconds 1500

# Open Add Memory form
Write-Output "==> [TEST 2 & 3] Opening Add Memory Form..."
& $adb -s $device shell input tap 954 214
Start-Sleep -Milliseconds 1200
& $adb -s $device shell input tap 540 2200
Start-Sleep -Milliseconds 1500

# Enter Title and Content
Write-Output "==> [TEST 3] Entering Title 'My First Memory' and Content..."
& $adb -s $device shell input tap 540 300
Start-Sleep -Milliseconds 600
& $adb -s $device shell input text "My%sFirst%sMemory"
Start-Sleep -Milliseconds 600

& $adb -s $device shell input tap 540 480
Start-Sleep -Milliseconds 600
& $adb -s $device shell input text "Test%scontent%sfor%smemory%stagging"
Start-Sleep -Milliseconds 600

& $adb -s $device shell input keyevent 111
Start-Sleep -Milliseconds 800

# TEST 4: Open People Selector and Tag Ahmed
Write-Output "==> [TEST 4] Opening Tag People Selector..."
& $adb -s $device shell input tap 203 1769
Start-Sleep -Milliseconds 1500
& $adb -s $device exec-out screencap -p > qa/screenshots/step2_people_selector.png

Write-Output "==> [TEST 4] Selecting Ahmed..."
& $adb -s $device shell input tap 400 1860
Start-Sleep -Milliseconds 1000
& $adb -s $device exec-out screencap -p > qa/screenshots/step4_person_selected.png

Write-Output "==> [TEST 4] Confirming People Selection (Done)..."
& $adb -s $device shell input tap 540 2100
Start-Sleep -Milliseconds 1200
& $adb -s $device exec-out screencap -p > qa/screenshots/step4_form_with_tagged_person.png

# TEST 5: Save Memory
Write-Output "==> [TEST 5] Saving Memory..."
& $adb -s $device shell input tap 540 2280
Start-Sleep -Milliseconds 3000
& $adb -s $device exec-out screencap -p > qa/screenshots/step5_memory_saved_in_list.png

# TEST 6: Memory Details
Write-Output "==> [TEST 6] Opening Memory Details for 'My First Memory'..."
& $adb -s $device shell input tap 540 700
Start-Sleep -Milliseconds 1800
& $adb -s $device exec-out screencap -p > qa/screenshots/step6_memory_details.png

Write-Output "==> [TEST 6] Closing Memory Details Sheet..."
& $adb -s $device shell input keyevent 4
Start-Sleep -Milliseconds 1200

# TEST 7: Search by Person
Write-Output "==> [TEST 7] Testing Search by Person 'ahmed'..."
& $adb -s $device shell input tap 833 210
Start-Sleep -Milliseconds 1000
& $adb -s $device shell input text "ahmed"
Start-Sleep -Milliseconds 1500
& $adb -s $device exec-out screencap -p > qa/screenshots/step7_search_results.png

Write-Output "==> [TEST 7] Closing Search..."
& $adb -s $device shell input keyevent 4
Start-Sleep -Milliseconds 1200

# TEST 8: Rename Person to "Ahmed Ali"
Write-Output "==> [TEST 8] Opening People Selector to Rename Person..."
& $adb -s $device shell input tap 954 214
Start-Sleep -Milliseconds 1200
& $adb -s $device shell input tap 540 2200
Start-Sleep -Milliseconds 1500
& $adb -s $device shell input tap 203 1769
Start-Sleep -Milliseconds 1500

Write-Output "==> [TEST 8] Tapping Edit Pencil..."
& $adb -s $device shell input tap 812 1860
Start-Sleep -Milliseconds 1500
& $adb -s $device exec-out screencap -p > qa/screenshots/step8_rename_dialog.png

Write-Output "==> [TEST 8] Typing New Name 'Ahmed Ali' and Saving..."
for ($i=0; $i -lt 10; $i++) { & $adb -s $device shell input keyevent 67 }
Start-Sleep -Milliseconds 400
& $adb -s $device shell input text "Ahmed%sAli"
Start-Sleep -Milliseconds 600

# Tap Save in dialog (X=715, Y=580)
& $adb -s $device shell input tap 715 580
Start-Sleep -Milliseconds 1500

# Tap Done (X=540, Y=2100)
& $adb -s $device shell input tap 540 2100
Start-Sleep -Milliseconds 1000

# Close Add Memory sheet
& $adb -s $device shell input keyevent 4
Start-Sleep -Milliseconds 1200

# TEST 9: Verify updated name appears in Memory Details
Write-Output "==> [TEST 9] Verifying Updated Name 'Ahmed Ali' in Memory Details..."
& $adb -s $device shell input tap 540 700
Start-Sleep -Milliseconds 1800
& $adb -s $device exec-out screencap -p > qa/screenshots/step9_memory_details_renamed.png
& $adb -s $device shell input keyevent 4
Start-Sleep -Milliseconds 1200

# TEST 10 & 11: Delete Person and Verify Memory Detached
Write-Output "==> [TEST 10] Deleting Person 'Ahmed Ali' via Supabase..."
$people = Invoke-RestMethod -Uri "https://jaxmuqfoqvctezlxbcts.supabase.co/rest/v1/people?select=*" -Headers $headers
$targetPerson = $people | Where-Object { $_.name -match "Ahmed|ahmed" } | Select-Object -First 1
if ($targetPerson) {
    Write-Output "Found target person ID: $($targetPerson.id) ($($targetPerson.name)), deleting..."
    Invoke-RestMethod -Uri "https://jaxmuqfoqvctezlxbcts.supabase.co/rest/v1/people?id=eq.$($targetPerson.id)" -Method Delete -Headers $headers
}

Start-Sleep -Milliseconds 1000

# Pull to refresh memories screen
Write-Output "==> [TEST 11] Pulling to Refresh Memories Screen..."
& $adb -s $device shell input swipe 540 600 540 1800 300
Start-Sleep -Milliseconds 2500
& $adb -s $device exec-out screencap -p > qa/screenshots/step10_person_deleted_from_filters.png

Write-Output "==> [TEST 11] Verifying Memory Remains Intact Without Deleted Person..."
& $adb -s $device shell input tap 540 700
Start-Sleep -Milliseconds 1800
& $adb -s $device exec-out screencap -p > qa/screenshots/step11_memory_remains_intact.png
& $adb -s $device shell input keyevent 4
Start-Sleep -Milliseconds 1200

# TEST 12: Visual & Navigation Sanity
Write-Output "==> [TEST 12] Performing Tab Navigation Sanity Checks..."
# Home
& $adb -s $device shell input tap 108 2200
Start-Sleep -Milliseconds 1500
& $adb -s $device exec-out screencap -p > qa/screenshots/step12_home.png

# Vault
& $adb -s $device shell input tap 324 2200
Start-Sleep -Milliseconds 1500
& $adb -s $device exec-out screencap -p > qa/screenshots/step12_vault.png

# Memories
& $adb -s $device shell input tap 756 2200
Start-Sleep -Milliseconds 1500
& $adb -s $device exec-out screencap -p > qa/screenshots/step12_memories.png

Write-Output "==> Stopping Screen Recording..."
& $adb -s $device shell pkill -2 screenrecord
Start-Sleep -Seconds 3

Write-Output "==> Pulling Video Recording from Device..."
& $adb -s $device pull /sdcard/everkeep_people_tagging_test.mp4 qa/everkeep_people_tagging_test.mp4
Get-Item qa/everkeep_people_tagging_test.mp4 | Select-Object Name, Length, LastWriteTime
Write-Output "==> E2E Video QA Execution Completed Successfully!"
