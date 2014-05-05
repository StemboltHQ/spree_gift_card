Spree.user_class.class_eval do
  has_many :gift_cards,
    ->{ includes(line_item: :order).
        where("spree_orders.payment_state != 'balance_due' OR spree_gift_cards.line_item_id is null").
        references(:orders) },
    foreign_key: "user_id"

  def available_gift_cards
    gift_cards.active
  end
end
