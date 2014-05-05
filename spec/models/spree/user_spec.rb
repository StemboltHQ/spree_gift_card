require 'spec_helper'

describe Spree::User do
  describe "has_many gift cards" do
    let!(:user) { create :user }
    let!(:gift_card) { create :gift_card, user: user }

    subject { user.gift_cards.reload }

    context "when gift cards were purchased in an order" do
      let!(:product) { create :product, is_gift_card: true }
      let!(:line_item) { create :line_item, product: product, order: order, gift_card: gift_card }

      before do
        gift_card.update_attributes(line_item: line_item)
      end

      context "has an outtanding balance" do
        let!(:order) { create :order }

        it "they are not included in the association query" do
          expect(subject).to_not include(gift_card)
        end
      end

      context "when the order doesn't have an outstanding balance" do
        let!(:order) { create :order_ready_to_ship }

        it "they are included in the association query" do
          expect(subject).to include(gift_card)
        end
      end
    end

    context "when gift cards are created by administrators" do
      it "is included in the association query" do
        expect(subject).to include(gift_card)
      end
    end
  end

  describe "#available_gift_cards" do
    let(:user) { create :user }
    let(:order) { create :order, user: user }

    subject { order.available_gift_cards }

    context "for a user with a expired gift card that has a value" do
      let!(:gift_card) { create :expired_gc, user: user }

      it "isn't included in the results" do
        expect(subject.to_a).to be_empty
      end
    end

    context "for a user with a unexpired gift card that has no value" do
      let!(:gift_card) { create :redeemed_gc, user: user }

      it "isn't included in the results" do
        expect(subject.to_a).to be_empty
      end
    end

    context "for a user with a gift card that has value and is unexpired" do
      let!(:gift_card) { create :gift_card, user: user }

      it "is included in the results" do
        expect(subject.to_a).to eql([gift_card])
      end
    end
  end
end
