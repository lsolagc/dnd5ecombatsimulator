module Combat
  # A reroll the participant may use (glossary: Reroll): the feature whose uses it spends and when it applies
  # (ClassFeatureUnlock::EFFECT_KINDS "reroll"). Read by Combat::FeatureBook#rerolls, used by Combat::SavingThrow.
  Reroll = Data.define(:class_feature_id, :when)
end
