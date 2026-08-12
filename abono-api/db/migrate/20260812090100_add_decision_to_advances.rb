# The eligibility decision as it stood when the advance was requested.
#
# Kept because the decision is an audit record, not a derived value: policy
# changes, attendance data is re-synced, balances move. Re-running the engine
# next month would not reproduce why this request was answered the way it was,
# and "why was I declined" is a question an employee is entitled to a straight
# answer to.
class AddDecisionToAdvances < ActiveRecord::Migration[8.1]
  def change
    add_column :advances, :decision, :jsonb
  end
end
