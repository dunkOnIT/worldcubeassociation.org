# frozen_string_literal: true

module CompetitionsHelper
  def competition_message_for_user(competition, user, registration = nil)
    # Generates a list of messages, which will be combined and displayed in a tooltip to the user in their bookmarked
    # competitions list when they hover over a competition.
    # Message indicates the state of the competition, and the state of the user's registration.

    messages_to_join = []

    return t('competitions.messages.cancelled') if competition.cancelled? # If the competition is cancelled, that's the only string we need to show the user.

    messages_to_join << get_registration_status_message_if_registered(competition, user, registration)
    messages_to_join << get_competition_status_message(competition)

    messages_to_join.join(' ')
  end

  def pretty_print_result(result, short: false)
    event = result.event
    sort_by = result.format.sort_by

    # If the format for this round was to sort by average, but this particular
    # result did not achieve an average, then switch to "best", and do not allow
    # a short format (to make it clear what happened).
    if sort_by == "average" && result.to_solve_time(:average).incomplete?
      sort_by = "single"
      short = false
    end

    solve_time = nil
    a_win_by_word = nil
    case sort_by
    when "single"
      solve_time = result.to_solve_time(:best)
      a_win_by_word = if event.multiple_blindfolded?
                        t('competitions.competition_info.result')
                      else
                        t('competitions.competition_info.single')
                      end
    when "average"
      solve_time = result.to_solve_time(:average)
      a_win_by_word = result.format.id == "a" ? t('competitions.competition_info.average') : t('competitions.competition_info.mean')
    end

    if short
      solve_time.clock_format
    else
      t('competitions.competition_info.result_sentence', a_win_by_word: a_win_by_word, result: solve_time.clock_format_with_units)
    end
  end

  def people_to_sentence(results)
    results
      .sort_by(&:person_name)
      .map { |result| "[#{result.person_name}](#{person_url result.person_id})" }
      .to_sentence
  end

  def winners(competition, main_event)
    top_three = competition.results.where(event: main_event).podium.order(:pos)
    results_by_place = top_three.group_by(&:pos)

    return t('competitions.competition_info.no_winner', event_name: main_event.name) if results_by_place.blank?

    winners = results_by_place[1]
    text = t('competitions.competition_info.winner', winner: people_to_sentence(winners),
                                                     result_sentence: pretty_print_result(winners.first),
                                                     event_name: main_event.name)
    if results_by_place[2]
      text += " #{t('competitions.competition_info.first_runner_up',
                    first_runner_up: people_to_sentence(results_by_place[2]),
                    first_runner_up_result: pretty_print_result(top_three.second, short: true))}"
      if results_by_place[3]
        text += " #{t('competitions.competition_info.and')}"
        text += " #{t('competitions.competition_info.second_runner_up',
                      second_runner_up: people_to_sentence(results_by_place[3]),
                      second_runner_up_result: pretty_print_result(top_three.third, short: true))}"
      else
        text += "."
      end
    elsif results_by_place[3]
      text += " #{t('competitions.competition_info.second_runner_up',
                    second_runner_up: people_to_sentence(results_by_place[3]),
                    second_runner_up_result: pretty_print_result(top_three.third, short: true))}"
    end

    text
  end

  def records(competition)
    text = ""
    codes = ["WR", "AfR", "AsR", "OcR", "ER", "NAR", "SAR"]
    codes.each do |code|
      comp_records = competition.results.where('regional_single_record=:code OR regional_average_record=:code', code: code)
      unless comp_records.empty?
        text += t("competitions.competition_info.records.#{code.downcase}")
        text += ": "
        record_strs = comp_records.group_by(&:person_name).sort.map do |person_name, results_for_name|
          results_by_person_id = results_for_name.group_by(&:person_id).sort
          results_by_person_id.map do |person_id, results|
            unique_name = if results_by_person_id.length > 1
                            # Two or more people with the same name set records at this competition!
                            # Append their WCA IDs to distinguish between them.
                            "[#{person_name} (#{person_id})](#{person_url person_id})"
                          else
                            "[#{person_name}](#{person_url person_id})"
                          end
            record_strs = results.sort_by do |r|
              round_type = RoundType.c_find(r.round_type_id)
              [Event.c_find(r.event_id).rank, round_type.rank]
            end.map do |result|
              event = Event.c_find(result.event_id)
              record_strs = []
              record_strs << t('competitions.competition_info.regional_single_record', event_name: event.name, result: (result.to_s :best)) if result.regional_single_record == code
              record_strs << t('competitions.competition_info.regional_average_record', event_name: event.name, result: (result.to_s :average)) if result.regional_average_record == code
              record_strs
            end.flatten
            "#{unique_name}&lrm; #{record_strs.to_sentence}"
          end
        end
        text += "#{record_strs.join("; ")}.  \n" # Trailing spaces for markdown give us a <br>
      end
    end

    text
  end

  def announced_content(competition)
    competition.announced_at ? "#{pluralize(days_announced_before_competition(competition), "day")} before" : ""
  end

  def announced_class(competition)
    if competition.announced_at
      level = [Competition::ANNOUNCED_DAYS_WARNING, Competition::ANNOUNCED_DAYS_DANGER].count { |d| days_announced_before_competition(competition) > d }
      ["alert-danger", "alert-orange", "alert-green"][level]
    else
      ""
    end
  end

  private def report_and_results_days_to_class(days)
    level = [Competition::REPORT_AND_RESULTS_DAYS_OK, Competition::REPORT_AND_RESULTS_DAYS_WARNING, Competition::REPORT_AND_RESULTS_DAYS_DANGER].count { |d| days > d }
    ["alert-green", "alert-success", "alert-orange", "alert-danger"][level]
  end

  def report_content(competition)
    days_report = days_after_competition(competition.delegate_report.posted_at, competition)
    if days_report
      submitted_by_competition_delegate = competition.delegates.include?(competition.delegate_report.posted_by_user)
      submitted_by_competition_delegate ? "#{pluralize(days_report, "day")} after" : "submitted by other"
    else
      competition.probably_over? ? "pending" : ""
    end
  end

  def report_class(competition)
    days_report = days_after_competition(competition.delegate_report.posted_at, competition)
    if days_report
      report_and_results_days_to_class(days_report)
    elsif competition.probably_over?
      days_report = days_after_competition(Date.today, competition)
      report_and_results_days_to_class(days_report)
    else
      ""
    end
  end

  def results_content(competition)
    days_results = days_after_competition(competition.results_submitted_at, competition)
    if days_results
      "#{pluralize(days_results, "day")} after"
    else
      competition.probably_over? ? "pending" : ""
    end
  end

  def results_class(competition)
    return "" unless competition.probably_over?

    days_results = days_after_competition(competition.results_posted_at, competition)
    days_results ? report_and_results_days_to_class(days_results) : ""
  end

  def year_is_a_number?(year)
    year.is_a?(Integer) || year =~ /\A\d+\z/
  end

  def competitions_json_for_markers(competitions)
    competitions.map do |c|
      {
        id: c.id,
        name: c.name,
        latitude_degrees: c.latitude_degrees,
        longitude_degrees: c.longitude_degrees,
        city_name: c.city_name,
        marker_date: wca_date_range(c.start_date, c.end_date),
        is_probably_over: c.probably_over?,
        url: competition_path(c),
      }
    end.to_json.html_safe
  end

  def first_and_last_time_from_activities(activities, timezone)
    # The goal of this function is to determine what should be the starting and ending points in the time axis of the calendar.
    # Which means we need to find the earliest start_time (and latest end_time) for any activity occuring on all days, expressed in the local timezone.
    # To do that we first convert the start_time to the local timezone, and keep only the "time of the day" component of the datetime.
    # We can sort the activities based on this value to compute the extremum of the time axis.
    sorted_activities = activities.sort_by { |a| a.start_time.in_time_zone(timezone).strftime("%H:%M") }
    first_activity = sorted_activities.first
    first_time = if first_activity
                   first_activity.start_time.in_time_zone(timezone).strftime("%H:00:00")
                 else
                   "08:00:00"
                 end
    last_activity = sorted_activities.last
    last_time = if last_activity
                  last_timestamp = last_activity.end_time.in_time_zone(timezone)
                  if last_timestamp.hour == 0 && last_timestamp.min == 0
                    "23:59:59"
                  else
                    last_timestamp.strftime("%H:59:59")
                  end
                else
                  "20:00:00"
                end
    [first_time, last_time]
  end

  def playwright_connection(&)
    if Rails.env.production? || EnvConfig.PLAYWRIGHT_RUN_LOCALLY?
      local_cli_path = "#{EnvConfig.PLAYWRIGHT_BROWSERS_PATH}/node_modules/playwright/cli.js"

      Playwright.create(playwright_cli_executable_path: local_cli_path) do |playwright|
        playwright.chromium.launch(headless: true, channel: 'chromium', &)
      end
    else
      endpoint_url = "#{EnvConfig.PLAYWRIGHT_SERVER_SOCKET_URL}?browser=chromium"

      Playwright.connect_to_playwright_server(endpoint_url) do |playwright|
        playwright.chromium.launch(headless: true, channel: 'chromium', &)
      end
    end
  end

  def create_pdfs_directory
    FileUtils.mkdir_p(CleanupPdfs::CACHE_DIRECTORY) unless File.directory?(CleanupPdfs::CACHE_DIRECTORY)
  end

  def path_to_cached_pdf(competition, colors)
    CleanupPdfs::CACHE_DIRECTORY.join("#{cached_pdf_name(competition, colors)}.pdf")
  end

  def pdf_name(competition)
    "#{competition.id}_#{I18n.locale}"
  end

  def cached_pdf_name(competition, colors)
    "#{pdf_name(competition)}_#{competition.updated_at.iso8601}_#{colors}"
  end

  def registration_status_icon(competition)
    icon = ""
    title = ""
    icon_class = ""

    if competition.registration_not_yet_opened?
      icon = "clock"
      title = I18n.t('competitions.index.tooltips.registration.opens_in', duration: distance_of_time_in_words_to_now(competition.registration_open))
      icon_class = "blue"
    elsif competition.registration_past?
      icon = "user times"
      title = I18n.t('competitions.index.tooltips.registration.closed', days: t('common.days', count: (competition.start_date - Date.today).to_i))
      icon_class = "red"
    elsif competition.registration_full?
      icon = "user clock"
      title = I18n.t('competitions.index.tooltips.registration.full')
      icon_class = "orange"
    else
      icon = "user plus"
      title = I18n.t('competitions.index.tooltips.registration.open')
      icon_class = "green"
    end

    ui_icon(icon,
            title: title,
            class: icon_class,
            data: { toggle: "tooltip" })
  end

  def link_to_add_series_association(competition)
    button = button_tag(t('competitions.competition_series_fields.add_series'), type: "button", class: "btn btn-default")
    form = send(:instantiate_builder, "competition", competition, {
                  builder: SimpleForm::FormBuilder,
                  wrapper: :horizontal_form,
                })

    # force_non_association_create makes it so that the `series` association is not constantly deleted
    # and re-created upon opening the form. See also https://github.com/nathanvda/cocoon/wiki/has_one-association
    link_to_add_association button, form, :competition_series,
                            data: { association_insertion_node: '.series', association_insertion_method: 'prepend' },
                            render_options: { preload_competition_id: competition.id },
                            force_non_association_create: true
  end

  def preload_competition_series(form_competition, preload_competition_id)
    competition = Competition.find_by(id: preload_competition_id)

    if (series = competition.competition_series)
      form_competition.competition_series = series

      # Hack around Rails reverse has_one associations
      # because our form_competition is not the actual persisted competition
      new_competitions = series.competitions | [form_competition]
      competition_ids = new_competitions.map(&:id).join(',')

      series.competition_ids = competition_ids

      return series
    end

    CompetitionSeries.new(competitions: [form_competition, competition])
  end

  def result_cache_key(competition, view, is_admin: false)
    [view, competition.id, competition.results || [], I18n.locale, is_admin]
  end

  private

    def get_registration_status_message_if_registered(competition, user, registration = nil)
      # Helper function for `competition_message_for_user`
      # Determines what message to display to the user based on the state of their registration.

      registration_status = registration || competition.registrations.find_by(user_id: user.id)
      return if registration_status.blank?

      if registration_status.accepted?
        t('competitions.messages.tooltip_registered')
      elsif registration_status.cancelled? || registration_status.rejected?
        t('competitions.messages.tooltip_deleted')
      elsif registration_status.waitlisted?
        t('competitions.messages.tooltip_waiting_list')
      else
        t('competitions.messages.tooltip_pending')
      end
    end

    def get_competition_status_message(competition)
      # Helper function for `competition_message_for_user`
      # Returns a string indicating (a) whether the competition is visible, and
      # (b) whether the competition is confirmed, based on the competition's state.

      visible = competition.show_at_all?

      if competition.confirmed?
        visible ? t('competitions.messages.confirmed_visible') : t('competitions.messages.confirmed_not_visible')
      else
        visible ? t('competitions.messages.not_confirmed_visible') : t('competitions.messages.not_confirmed_not_visible')
      end
    end

    def days_before_competition(date, competition)
      date ? (competition.start_date - date.to_date).to_i : nil
    end

    def days_after_competition(date, competition)
      date ? (date.to_date - competition.end_date).to_i : nil
    end

    def days_announced_before_competition(competition)
      days_before_competition(competition.announced_at, competition)
    end
end
