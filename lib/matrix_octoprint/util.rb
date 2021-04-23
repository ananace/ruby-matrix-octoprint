# frozen_string_literal: true

require 'ostruct'

class DeepOpenStruct < OpenStruct
  def self.parse(value)
    case value
    when Hash
      new(value)
    when Array
      value.map do |v|
        parse(v)
      end
    else
      value
    end
  end

  def initialize(source)
    struct = {}

    source.each do |k, v|
      struct[k] = self.class.parse(v)
    end

    super(struct)
  end

  def first
    @table.first
  end

  def key?(key)
    respond_to? key.to_s.to_sym
  end

  def to_h
    @table.map do |k, v|
      v = v.to_h if v.is_a? DeepOpenStruct
      [k, v]
    end.to_h
  end
end

class Numeric
  def as_duration
    secs  = to_int
    mins  = secs / 60
    hours = mins / 60
    days  = hours / 24

    fdata = {
      secs: secs % 60,
      mins: mins % 60,
      hours: hours % 60,
      days: days % 60
    }

    if days.positive?
      format('%<days>d:%<hours>02d:%<mins>02d:%<secs>02d', fdata)
    elsif hours.positive?
      format('%<hours>02d:%<mins>02d:%<secs>02d', fdata)
    elsif mins.positive?
      format('%<mins>02d:%<secs>02d', fdata)
    elsif secs >= 0
      format('00:%<secs>02d', fdata)
    end
  end

  def as_length
    millis = to_int
    centis = millis / 10.0
    decis = centis / 10.0
    metres = decis / 10.0

    if metres > 0.75
      "#{metres.round(2)}m"
    elsif decis > 0.75
      "#{decis.round(2)}dm"
    elsif centis > 0.75
      "#{centis.round(2)}cm"
    else
      "#{millis}mm"
    end
  end

  def as_size
    bytes = to_int
    kb = bytes / 1024
    mb = kb / 1024.0

    if mb >= 0.25
      "#{mb.round(1)}MB"
    elsif kb.positive?
      "#{kb}KB"
    else
      "#{bytes}B"
    end
  end
end
