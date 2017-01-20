# -*- coding: utf-8 -*-
require_relative 'lecture'
require_relative 'osc'
require_relative 'scrape_mixin'

module Plugin::OSCTimetable
  class Timetable < Retriever::Model
    include Plugin::OSCTimetable::ScrapeMixin

    field.int :id
    field.string :title
    field.uri :perma_link
    field.has :osc, Plugin::OSCTimetable::OpenSourceConference

    def lectures
      dom.next do |doc|
        parse_table(doc.xpath("//table[@class='outer']").first)
      end
    end

    def schedule
      osc.schedules[id - 1]
    end

    def inspect
      "#<#{self.class}: #{title} #{schedule.inspect}>"
    end

    private

    def parse_table(table)
      table_title = table.css('caption').text
      places = table.css('tr').first.css('th').map { |th| th.text.gsub(/(\s|　)+/, '') }
      table.css('tr').first.remove

      table.css('tr').map do |lec|
        period = lec.css('th').text.gsub(/(\s|　)+/, '').match(/(?<start_hour>\d{1,2}):(?<start_min>\d{1,2})\-(?<end_hour>\d{1,2}):(?<end_min>\d{1,2})/)

        lec.css('td').reject{|l|
          l.css('a').first.to_s.empty?
        }.map do |l|
          link = l.css('a').first[:href]
          id = link.match(/[\w\-]+\?eid=([0-9]).*/)
          title = l.css('a').first.text
          belonging = l.text.split(/\r/)[0].gsub(/.*担当：/, '')
          t_name = l.text.split(/\r/)[1].gsub(/^講師：/, '')

          teacher = Plugin::OSCTimetable::Teacher.new(name: t_name,
                                                      belonging: belonging)
          Plugin::OSCTimetable::Lecture.new(id: id,
                                            title: title,
                                            teacher: [teacher],
                                            perma_link: link,
                                            start: lecture_time(schedule.start, period['start_hour'], period['start_min']),
                                            end: lecture_time(schedule.end, period['end_hour'], period['end_min']))
        end
      end
    end

    def lecture_time(time, hour, min)
      Time.new(time.year, time.month, time.day, hour, min, time.sec, time.utc_offset)
    end

  end
end
