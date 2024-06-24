require 'selenium-webdriver'
require 'json'
require 'time'
require 'logger'

ELEMENT_TIMEOUT = 10
RESULT_STAY = 600
DEFAULT_REFRESH_INTERVAL = 150
DATE_RANGE = 3

module Colorize
  COLORS = {
    red: 31,
    green: 32,
    yellow: 33,
    blue: 34,
    magenta: 35,
    cyan: 36,
    white: 37
  }

  def self.colorize(text, color)
    color_code = COLORS[color]
    "\e[#{color_code}m#{text}\e[0m"
  end
end

def start
    output = "Start checking road test availability at #{Time.now}"
    puts output
    @elogger = Logger.new("error.log")
    @elogger << "\n" + "=" * 80 + "\n"
    @elogger << output + "\n"
    @slogger = Logger.new("success.log")
    @slogger << "\n" + "=" * 80 + "\n"
    @slogger << output + "\n"

    setup
    count = 0
    while true
        count += 1
        prompt = "Refresh count #{count} "
        print prompt
        success = false
        begin
            success = check
        rescue Exception => e
            output = ": error "
            print output
            prompt += output # for print dots later
            @elogger << "\nRound #{count}: #{e}"
            cleanup
            setup
        end

        unless success
            interval = ARGV[3]
            dots = 80 - prompt.size
            pause = (interval || DEFAULT_REFRESH_INTERVAL).to_f/dots
            dots.times do 
                sleep pause
                putc "."
            end
        end
        puts ""
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
    name,id,key = ARGV[0,3]
    @driver.find_element(:id, 'mat-input-1').send_keys(id)
    @driver.find_element(:id, 'mat-input-2').send_keys(key)
    @driver.find_element(:id, 'mat-input-0').click
    @driver.find_element(:id, 'mat-input-0').send_keys(name)
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
        return false
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
        output = "----------------------------------------------------------"
        puts "\n" + output
        @slogger << output + "\n"
        output = "#{Time.now}"
        puts output
        @slogger << output + "\n"
        output = "Found an appointment: #{date} #{time}"
        puts output
        @slogger << output + "\n"
        output = "Current  appointment: #{current_date} #{current_time}"
        puts output
        @slogger << output + "\n"
        output = "----------------------------------------------------------"
        puts output
        @slogger << output + "\n"
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
        return true
    end
    return false
end
start