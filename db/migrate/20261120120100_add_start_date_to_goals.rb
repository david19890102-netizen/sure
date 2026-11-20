class AddStartDateToGoals < ActiveRecord::Migration[8.1]
  def change
    add_column :goals, :start_date, :date
  end
end
