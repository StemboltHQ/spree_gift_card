class AddDeletedToGiftCards < ActiveRecord::Migration
  def change
    add_column :spree_gift_cards, :is_deleted, :boolean, default: false
    add_index :spree_gift_cards, :is_deleted
  end
end
