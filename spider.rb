require 'nokogiri'
require 'rest_client'
require 'capybara'
require 'pry'
require 'capybara/poltergeist'
require 'ruby-progressbar'

class Spider
  include Capybara::DSL
  attr_accessor :courses

  def initialize
    # Capybara.register_driver :poltergeist_with_long_timeout do |app|
    #   Capybara::Poltergeist::Driver.new(app, :timeout => 300)
    # end

    # Capybara.default_driver = :poltergeist_with_long_timeout
    # Capybara.javascript_driver = :poltergeist_with_long_timeout
    # Capybara.default_wait_time = 2
    Capybara.default_driver = :selenium
    @courses = []
  end

  def crawl
    # page.visit "http://studentsystem.usc.edu.tw/CourseSystem/Index.htm"
    page.visit "http://studentsystem.usc.edu.tw/CourseSystem/Top.asp"
    options = page.all('select')[2].all('option')[1..-1]

    main = page.driver.browser.window_handles.first
    options.each do |option|
      begin
        option.select_option
        click_on '課程搜尋'

        popup = page.driver.browser.window_handles.last
        page.driver.browser.switch_to.window(popup)


        parse_table(page)
        # binding.pry

        page.driver.browser.close
        page.driver.browser.switch_to.window(main)
      rescue Exception => e
        redo
      end
    end

    binding.pry
  end

  def parse_table(page)
    doc = Nokogiri::HTML(page.html)
    rows = doc.css('tr:nth-child(n+4)')
    rows.each do |row|
      columns = row.css('td')
      begin
        match_raws = columns[9].text.strip.split('/').map {|s|
          s.match(/(?<day>[一二三四五六日]|)\((?<periods>.+)\)(?<classroom>$|.+)/)
        }
      rescue
        next
      end
      schedule = []
      match_raws.each do |mat|
        begin
          mat["periods"].split(',').each do |period|
            schedule << {
              day: mat["day"],
              period: period,
              classroom: mat["classroom"],
            }
          end
        rescue
        end
      end

      url = columns[3].css('a')[0]["href"] if not columns[3].css('a').empty?

      @courses << {
        :serial_no => columns[0].text.strip,
        :class => columns[1].text.strip,
        :group => columns[2].text.strip,
        :name => columns[3].text.strip,
        :url => "http://studentsystem.usc.edu.tw/CourseSystem/#{url}",
        :required => columns[5].text.include?('必'),
        :credits => Integer(columns[6].text.strip),
        :hours => Integer(columns[7].text.strip),
        :lecturer => columns[8].text.strip,
        :schedule => schedule,
        :note => columns[15].text.strip
      }
    end
  end

  def crawl_detail
    @courses = JSON.parse File.read('courses.json')
    progressbar = ProgressBar.create(:total => @courses.count)
    @courses.each do |course|
      progressbar.increment
      begin
        r = RestClient.get course["url"]
        doc = Nokogiri::HTML(r.to_s)

      rescue Exception => e
        redo
      end

      begin
        rows = doc.css('tr')
        course_title_row = doc.css('tr:contains("Materials")').last
        textbook_row = rows[rows.index(course_title_row) + 1]
        textbook_row.search('br').each {|k| k.replace("\n")}
        course["textbook"] = textbook_row.text.strip
      rescue Exception => e

      end

      begin
        reference_title_row = doc.css('tr:contains("References")').first
        reference_row = rows[reference_title_row + 3]
        reference_row.search('br').each {|k| k.replace("\n")}
        course["references"] = reference_row.text.strip
      rescue Exception => e

      end

    end
  end


end

spider = Spider.new
# spider.crawl
spider.crawl_detail
binding.pry
