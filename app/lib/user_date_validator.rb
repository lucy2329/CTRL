module UserDateValidator
  def date_of_birth_in_future
    return false unless valid_date_of_birth?(:dob)

    !dob.future? ? true : errors.add(:dob, I18n.t('user.errors.dob.future')) && false
  end

  def child_date_of_birth_in_future
    return false unless is_parent && date_valid?(:child_dob)

    !child_dob.future? ? true : errors.add(:child_dob, I18n.t('user.errors.dob.future')) && false
  end

  def check_study_code
    codes = StudyCode.pluck(:title)
    if codes.all? { |code| Regexp.new(code).match(study_id) }
      true
    else
      errors.add(:study_id, 'Please check Study ID')
      false
    end
  end

  private

  def date_valid?(dob)
    date_format = /\d{2}-\d{2}-(\d{4})$/
    send(dob).to_s.match?(date_format) ? true : errors.add(dob, I18n.t('user.errors.dob.invalid_format')) && false
  end

  def valid_date_of_birth?(dob)
    send(dob).is_a?(Date) ? true : errors.add(dob, I18n.t('user.errors.dob.invalid_format')) && false
  end
end
