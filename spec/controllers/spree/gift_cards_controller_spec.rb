require "spec_helper"

describe Spree::GiftCardsController do
  let(:user) { create :user}
  login

  describe "GET send_to_friend" do
    subject { get :send_to_friend, id: card.id, use_route: :spree }
    let!(:card) { create :gift_card, user: user }
    it { should be_success }
    it { should render_template :send_to_friend }
  end

  describe "PUT transfer" do
    subject { put :transfer,
              id: 1,
              gift_card: gift_card_attributes,
              use_route: :spree }

    let(:gift_card_attributes) do
      {
        email: email,
        name: 'joe',
        note: 'sup heres a gc',
        transfer_amount: transfer_amount
      }
    end


    let!(:transfer_amount) { 4 }
    let!(:gc_value) { 10 }
    let(:email) { "recipitent@email.com"}
    let!(:card) { create :gift_card,
                  id: 1,
                  user: user,
                  original_value: gc_value,
                  current_value: gc_value }

    it { should be_redirect }

    it "has a success message" do
      subject
      expect(flash[:success]).to be_true
    end

    it "sends an email to the recipitent notifying them they've received a gift card" do
      mailer = double
      mailer.should_receive(:deliver)

      expect(Spree::GiftCardMailer).to receive(:gift_card_transferred).
        with(an_instance_of(Spree::GiftCard), user.email).and_return(mailer)

      subject
    end

    it "sets the new cards expiration date to be the same as the original" do
      subject
      expect(Spree::GiftCard.last.expiration_date).to eq card.reload.expiration_date
    end

    it "deducts the transferred amount from the original gift card" do
      subject
      expect(card.reload.current_value).to eq 6.0
    end

    it "create a new gift card that is owned by the recipitent" do
      expect{subject}.to change{Spree::GiftCard.count}
      new_card = Spree::GiftCard.last
      expect(new_card.email).to eq email
      expect(new_card.name).to eq 'joe'
      expect(new_card.current_value).to eq 4.0
    end

    describe "the gift card transfer" do
      it "is created" do
        expect{subject}.to change{Spree::GiftCardTransfer.count}.by(1)
      end

      it "has a destination gift card" do
        subject
        expect(assigns(:gift_card).transferred_gift_cards).to have(1).items
      end

      it "has a source gift card" do
        subject
        expect(assigns(:gift_card).gift_card_transfers.first.source).to eql(assigns(:gift_card))
      end
    end

    context "with invalid parameters" do
      context "when the gift card being sent's balance is less than the transferred amount" do
        let(:gc_value) { 1.0 }
        before { subject }

        it "it re-renders the action" do
          should render_template :send_to_friend
        end

        it "sets the error flash" do
          expect(flash[:error]).to eql(Spree.t(:insufficient_balance))
        end

        it "doesn't change the original gift card" do
          expect(card.reload.current_value).to eq 1.0
        end

        it "doesn't create another gift card" do
          expect{subject}.to_not change{Spree::GiftCard.count}
        end
      end

      context "when the parameters are incomplete or the new gift card is invalid" do
        before do
          gift_card_attributes.delete(:email)
        end

        describe "the response" do
          before { subject }
          it "renders send_to_friend" do
            expect(response).to render_template(:send_to_friend)
          end

          it "sets the error flash" do
            expect(flash[:error]).to include("Email can't be blank")
          end
        end

        it "doesn't create a gift card" do
          expect{subject}.to_not change{Spree::GiftCard.count}
        end
      end
    end

    context "when the recipitent does have a matching user" do
      let!(:recipitent) { create :user, email: email }

      it "adds the gift card to the recipitent's account" do
        expect{subject}.to change{recipitent.gift_cards.count}.by( 1 )
      end
    end
  end

  describe "POST create" do
    let(:attributes) { attributes_for(:gift_card, email: user.email, variant_id: variant.id) }
    subject { post :create,
              gift_card: attributes,
              use_route: :spree }

    let(:variant) { create :variant }
    let(:gift_card) { Spree::GiftCard.last }

    context "with a successful request" do
      before do
        subject
      end

      describe "the response" do
        it "redirects to the cart" do
          expect(response).to redirect_to(spree.cart_path)
        end
      end

      describe "the gift card" do
        let(:gc) { assigns(:gift_card) }

        it "creates a new gift card" do
          expect(gc).to be_persisted
        end

        it "belongs to a line item" do
          expect(gc.line_item).to be
        end

        it "doesnt have a user associated with it" do
          expect(gc.user).to_not be
        end
      end
    end

    context "with an unsuccessful request" do
      before do
        attributes.delete(:name)
        subject
      end

      describe "the response" do
        it "renders the new action" do
          expect(response).to render_template(:new)
        end
      end

      describe "the gift card" do
        it "doesnt create a gift card" do
          expect(Spree::GiftCard.all.to_a).to be_empty
        end
      end
    end
  end

  describe "GET index" do
    subject { get :index, use_route: :spree }

    let!(:user) { create(:user) }
    let!(:gift_card) { create(:gift_card, user: user) }
    let!(:expired_gc) { create(:expired_gc, user: user) }

    before { allow(controller).to receive(:current_spree_user).and_return(user) }

    it { should render_template(:index) }
    it { should be_success }

    describe "when the user is not logged in" do
      let!(:user) { nil }

      it "redirects to the login path" do
        expect(subject).to redirect_to(spree.login_path)
      end

      it "sets the flash" do
        subject
        expect(flash[:notice]).to be
      end
    end

    describe "sorting" do
      subject { get :index, use_route: :spree, show_all: "true" }

      let!(:gift_card_2) { create :gift_card, user: user, expiration_date: Time.current + 1.year }
      let!(:redeemed_gc) { create :redeemed_gc, user: user }

      it "sorts gift_cards by status, and then expiration_date" do
        subject
        expect(assigns(:gift_cards).count).to eq 4
        expect(assigns(:gift_cards).first).to eq gift_card_2
        expect(assigns(:gift_cards)[1]).to eq gift_card
        expect(assigns(:gift_cards)[-2]).to eq redeemed_gc
        expect(assigns(:gift_cards).last).to eq expired_gc
      end
    end

    context "when show_all query param isn't true" do
      it "doesn't include expired gift cards" do
        subject
        expect(assigns(:gift_cards).count).to eq 1
        expect(assigns(:gift_cards)).to_not include(expired_gc)
      end
    end

    context "when show_all query param is true" do
      subject { get :index, show_all: "true",
                use_route: :spree }

      it "includes expired gift cards as well" do
        subject
        expect(assigns(:gift_cards).count).to eq 2
        expect(assigns(:gift_cards)).to include(expired_gc)
      end
    end
  end
end
