require 'selenium-webdriver'
require 'json'
require 'time'

NAME = 'ZHANG'
ID = '09921100'
KEY = 'NI'

ELEMENT_TIMEOUT = 10
RESULT_STAY = 600
REFRESH_INTERVAL = 150
DATE_RANGE = 3

def start
    puts "Start checking road test availability at #{Time.now}"
    setup
    count = 0
    while true
        count += 1
        puts "Refresh count: #{count}"
        begin
            check
        rescue Exception => e
            puts e
            cleanup
            setup
        end

        sleep REFRESH_INTERVAL
    end
end

def setup
    @driver = Selenium::WebDriver.for :chrome
    @vars = {}
end

def cleanup
    @driver.quit
end

def check
    wait = Selenium::WebDriver::Wait.new(timeout: ELEMENT_TIMEOUT) # seconds
    @driver.get('https://onlinebusiness.icbc.com/webdeas-ui/login;type=driver')
    # @driver.manage.window.resize_to(1470, 913)
    @driver.manage.window.maximize

    # Login page
    @driver.find_element(:id, 'mat-input-1').send_keys(ID)
    @driver.find_element(:id, 'mat-input-2').send_keys(KEY)
    @driver.find_element(:id, 'mat-input-0').click
    @driver.find_element(:id, 'mat-input-0').send_keys(NAME)
    @driver.find_element(:css, '.mat-checkbox-inner-container').click
    @driver.find_element(:css, '.primary').click

    # Get current appointment date and time
    parent = wait.until{@driver.find_element(:css, '.appointment-time-label')}
    element = parent.find_element(:css, '.content:nth-child(2)')
    current_date = element.text
    element = parent.find_element(:css, '.content:nth-child(6)')
    current_time = element.text
    # Convert the date and time string to Time object
    current_date_time = Time.parse("#{current_date} #{current_time}")
    # puts "Current appointment at: #{current_date_time}"

    # Click "Reschedule" button
    wait.until{@driver.find_element(:css, '.raised-button:nth-child(1)')}.click
    # Click "Yes" button
    @driver.find_element(:css, '.form-control > .primary').click
    # Click "By Office" tab
    sleep 0.3
    wait.until{@driver.find_element(:css, '#mat-tab-label-2-1 > .mat-tab-label-content')}.click
    # Search "Burnaby claim centre" from the dropdown
    element = wait.until{@driver.find_element(:css, '#mat-input-4')}
    element.click
    element.send_keys('burnaby claim centre')
    # Click "Burnaby claim centre"
    wait.until{@driver.find_element(:css, '#mat-autocomplete-0 > .mat-option:first-child')}.click
    begin
        @driver.execute_script("window.scrollTo(0,0)")
        element = wait.until{@driver.find_element(:css, '.appointment-listings')}
    rescue Exception => e
        # puts e
        return
    end
    # Get the text of the first available date
    element = wait.until{@driver.find_element(:css, '.appointment-listings > .date-title')}
    ## puts element.html
    date = element.text
    ## puts "First available date: #{date}"
    # Get the text of the first available time
    element = @driver.find_element(:css, '#mat-button-toggle-1-button > .mat-button-toggle-label-content')
    time = element.text
    ## puts "First available time: #{time}"
    # Convert the date and time string to Time object
    # date_time = Time.strptime("#{date} #{time}", "%A, %B %d, %Y %I:%M %p")
    date_time = Time.parse("#{date} #{time}")
    ## puts "First available date and time: #{date_time}"
    if date_time < current_date_time + DATE_RANGE * 24 * 60 * 60
        puts "----------------------------------------------------------"
        puts "#{Time.now}"
        puts "Found an appointment: #{date} #{time}"
        puts "Current  appointment: #{current_date} #{current_time}"
        puts "----------------------------------------------------------"
        # Start booking
        # Click the time button
        element = @driver.find_element(:css, '#mat-button-toggle-1-button')
        element.click
        sleep 0.3
        # Click Review button
        element = @driver.find_element(:css, "button[value='2']")
        element.click
        # Click Next button
        element = wait.until{@driver.find_element(:css, ".action-button-container > .primary")}
        element.click
        # Email verification is selected by default
        # Click Send button
        element = wait.until{@driver.find_element(:css, ".form-control > .primary")}
        element.click
        sleep 1
        # Back to the select verification method page
        element = wait.until{ @driver.find_element(:css, ".form-control > .secondary") }
        element.click
        sleep 1
        # Select SMS verification
        elements = wait.until{@driver.find_elements(:css, ".radio-item-label")}
        elements[1].click
        # Click Send button
        element = @driver.find_element(:css, ".form-control > .primary")
        element.click
        # Wait for manually inputting the verification code
        sleep RESULT_STAY
    end
end

start