# Anything holding a gambit list (PlayerCharacter, GambitPreset) and its rules: at most
# Gambit::MAX_PER_OWNER (validated by Gambit#owner_has_room), at contiguous positions 1..n kept by the
# methods below. Every write of the positions runs in with_gambits_locked.
module GambitOwner
  extend ActiveSupport::Concern

  included do
    has_many :gambits, -> { order(:position) }, as: :owner, dependent: :destroy
  end

  # One transaction holding a row lock on the owner, so two concurrent requests can't both read the same
  # positions and write duplicates or gaps. The block reads the gambits after the lock (lock! reloads).
  def with_gambits_locked(&)
    transaction do
      lock!
      yield
    end
  end

  # A new last rule. Returns the gambit, saved or with its errors.
  def add_gambit(attributes)
    with_gambits_locked do
      Gambit.new(attributes.to_h.merge(owner: self, position: gambits.count + 1)).tap(&:save)
    end
  end

  # Swaps the gambit with its neighbor (direction :up/:down or "up"/"down"); at either end nothing moves.
  def move_gambit(gambit, direction)
    step = { "up" => -1, "down" => 1 }.fetch(direction.to_s)
    with_gambits_locked do
      list = gambits.to_a
      index = list.index(gambit) or raise ActiveRecord::RecordNotFound, "Gambit #{gambit.id} não é deste dono"
      other = index + step
      next false unless other.between?(0, list.size - 1)

      list[index], list[other] = list[other], list[index]
      rewrite_gambit_positions(list)
    end
  end

  # ids: the owner's gambit ids (integers) in their new order. Only an exact permutation of them is
  # accepted; anything else returns false, changing nothing.
  def reorder_gambits(ids)
    with_gambits_locked do
      by_id = gambits.index_by(&:id)
      ids.sort == by_id.keys.sort && rewrite_gambit_positions(by_id.values_at(*ids))
    end
  end

  # Destroys the gambit (raises ActiveRecord::RecordNotFound when it is another owner's) and closes the
  # gap (positions 1..n).
  def remove_gambit(gambit)
    with_gambits_locked do
      gambits.find(gambit.id).destroy!
      rewrite_gambit_positions(gambits.reload)
    end
  end

  # Replaces the rules with new copies of other's (presets: save, overwrite and apply). Copies take
  # positions 1..n in the source's priority order; being new rows, they keep no link to the source.
  # Returns false, changing nothing, when other has no rules. Each copy is validated here (a character's
  # level, see Gambit#active_feature_payload): the first one that does not hold raises
  # ActiveRecord::RecordInvalid, changing nothing.
  def copy_gambits_from(other)
    with_gambits_locked do
      rules = other.gambits.reorder(:position).map { |rule| rule.attributes.slice(*Gambit::SNAPSHOT_ATTRIBUTES).except("position") }
      next false if rules.empty?

      replace_gambits(rules)
      true
    end
  ensure
    gambits.reset
  end

  # Replaces the rules with the given ones (attribute hashes, priority order) at positions 1..n. Returns
  # the new gambits; the first that does not hold raises ActiveRecord::RecordInvalid, changing nothing.
  def replace_gambits(list_of_attributes)
    with_gambits_locked do
      gambits.delete_all
      list_of_attributes.each.with_index(1).map do |attributes, position|
        Gambit.create!(attributes.to_h.symbolize_keys.merge(owner: self, position:))
      end
    end
  ensure
    gambits.reset
  end

  private

    # Positions 1..n in the given order, every row written (the unique position constraint is deferred to
    # the commit). Call it inside with_gambits_locked. Returns true.
    def rewrite_gambit_positions(list)
      list.each.with_index(1) { |gambit, position| gambit.update_columns(position:, updated_at: Time.current) }
      true
    end
end
