class Competition < ActiveRecord::Base
  self.table_name = "Competitions"
  has_many :registrations, foreign_key: "competitionId"

  ends_with_year_re = /\A.* (19|20)\d{2}\z/
  pattern_link_re = /\[\{[^}]+}\{(https?:|mailto:)[^}]+}\]/
  pattern_text_with_links_re = /\A[^{}]*(#{pattern_link_re.source}[^{}]*)*\z/
  validates :name, length: { maximum: 50 },
                   format: { with: ends_with_year_re }
  validates :cellName, length: { maximum: 45 },
                       format: { with: ends_with_year_re }
  validates :venue, format: { with: pattern_text_with_links_re }
  validates :wcaDelegate, format: { with: pattern_text_with_links_re }
  validates :organiser, format: { with: pattern_text_with_links_re }
  validates :website, format: { with: pattern_text_with_links_re }

  attr_accessor :start_date, :end_date
  before_validation :unpack_dates
  validate :dates_must_be_valid
  validate :events_must_be_valid

  alias_attribute :latitude_microdegrees, :latitude
  alias_attribute :longitude_microdegrees, :longitude
  attr_accessor :longitude_degrees, :latitude_degrees
  before_validation :compute_coordinates

  def longitude_degrees
    longitude_microdegrees / 1e6
  end

  def longitude_degrees=(new_longitude_degrees)
    @longitude_degrees = new_longitude_degrees.to_f
  end

  def latitude_degrees
    latitude_microdegrees / 1e6
  end

  def latitude_degrees=(new_latitude_degrees)
    @latitude_degrees = new_latitude_degrees.to_f
  end

  private def compute_coordinates
    unless @latitude_degrees.nil?
      self.latitude_microdegrees = @latitude_degrees * 1e6
    end
    unless @longitude_degrees.nil?
      self.longitude_microdegrees = @longitude_degrees * 1e6
    end
  end

  def events
    # See https://github.com/cubing/worldcubeassociation.org/issues/95 for
    # what these equal signs are about.
    eventSpecs.split.map { |e| Event.find_by_id(e.split("=")[0]) }.sort_by &:rank
  end

  def start_date
    year == 0 || month == 0 || day == 0 ? "" : "%04i-%02i-%02i" % [ year, month, day ]
  end

  def end_date
    endYear = @endYear || year # gross hack to remember the years of a multiyear competition
    endYear == 0 || endMonth == 0 || endDay == 0 ? "" : "%04i-%02i-%02i" % [ endYear, endMonth, endDay ]
  end

  def start_date=(new_start_date)
    @start_date = new_start_date
  end

  def end_date=(new_end_date)
    @end_date = new_end_date
  end

  private def unpack_dates
    if @start_date.blank?
      self.year = self.month = self.day = 0
    else
      self.year, self.month, self.day = @start_date.split("-").map(&:to_i)
    end
    if @end_date.blank?
      @endYear = self.endMonth = self.endDay = 0
    else
      @endYear, self.endMonth, self.endDay = @end_date.split("-").map(&:to_i)
    end
  end

  private def dates_must_be_valid
    if self.year == 0 && self.month == 0 && self.day == 0 && @endYear == 0 && self.endMonth == 0 && self.endDay == 0
      # If the user left both dates empty, that's a-okay.
      return
    end

    valid_dates = true
    unless Date.valid_date? year, month, day
      valid_dates = false
      errors.add(:start_date, "Invalid start date.")
    end
    unless Date.valid_date? @endYear, endMonth, endDay
      valid_dates = false
      errors.add(:end_date, "Invalid end date.")
    end
    unless valid_dates
      # There's no use continuing validation at this point.
      return
    end

    if end_date < start_date
      errors.add(:end_date, "End date cannot be before start date.")
    end

    if @endYear != year
      errors.add(:end_date, "Competition dates cannot span multiple years.")
    end
  end

  private def events_must_be_valid
    invalid_events = events - Event.all_official - Event.all_deprecated
    unless invalid_events.empty?
      errors.add(:eventSpecs, "invalid event ids: #{invalid_events.map(&:id).join(',')}")
    end
  end
end
