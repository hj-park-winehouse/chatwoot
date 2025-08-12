class AddTranslationsToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :translations, :jsonb
  end
end
