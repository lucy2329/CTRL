require 'spec_helper'

RSpec.describe UploadRedcapDetails do
  describe '#call_api' do
    let(:mock_redcap_url) { 'example.com' }

    it 'does nothing when REDCAP_CONNECTION_ENABLED == false' do
      allow(HTTParty).to receive(:post)
      stub_const('REDCAP_CONNECTION_ENABLED', false)

      payload = {'this is' => 'a payload'}
      UploadRedcapDetails.call_api(payload)
      expect(HTTParty).not_to receive(:post)
    end

    it 'posts the payload when REDCAP_CONNECTION_ENABLED == true' do
      parsed_response = {'count' => 1}
      httparty = double('HTTParty', parsed_response: parsed_response)
      allow(httparty).to receive(:success?).and_return(true)
      allow(HTTParty).to receive(:post).and_return(httparty)
      stub_const('REDCAP_API_URL', mock_redcap_url)
      stub_const('REDCAP_CONNECTION_ENABLED', true)

      payload = {'this is' => 'a payload'}
      UploadRedcapDetails.call_api(payload)
      expect(HTTParty).to have_received(:post)
        .with(mock_redcap_url, body: payload)
    end

    it 'raises an exception when REDCap is down' do
      allow(HTTParty).to receive(:post).and_raise(HTTParty::Error)
      allow(Rollbar).to receive(:error)
      stub_const('REDCAP_API_URL', mock_redcap_url)
      stub_const('REDCAP_CONNECTION_ENABLED', true)

      payload = {'this is' => 'a payload'}

      expect {
        UploadRedcapDetails.call_api(payload)
      }.to raise_error(HTTParty::Error)

      expect(HTTParty).to have_received(:post)
        .with(mock_redcap_url, body: payload)
      expect(Rollbar).to have_received(:error)
        .with('Error connecting to REDCap - HTTParty::Error')
    end
  end

  describe '#make_redcap_api_payload' do
    it 'returns a payload when passed data' do
      mock_data = 'my data'
      mock_redcap_token = 'redcap token'

      stub_const('REDCAP_TOKEN', mock_redcap_token)
      expected_payload = {
        token: mock_redcap_token,
        content: 'record',
        format: 'json',
        type: 'flat',
        data: "\"my data\"",
      }

      expect(UploadRedcapDetails.make_redcap_api_payload(mock_data)).to eq(expected_payload)
    end

    it 'returns nil when passed nil' do
      expect(UploadRedcapDetails.make_redcap_api_payload(nil)).to eq(nil)
    end
  end

  describe '#answer_string_to_code' do
    it 'returns "1" for the answer string "Yes"' do
      expect(UploadRedcapDetails.answer_string_to_code('Yes')).to eq('1')
    end
    it 'returns "0" for the answer string "No"' do
      expect(UploadRedcapDetails.answer_string_to_code('No')).to eq('0')
    end
    it 'returns nil for an answer string other than "Yes" or "No"' do
      expect(UploadRedcapDetails.answer_string_to_code('Maybe')).to eq(nil)
    end
  end

  describe '#question_answer_to_redcap_response' do
    it 'passes the right arguments to construct_redcap_response' do
      question_answer = create(:question_answer, traits: [:multiple_checkboxes, :with_redcap_field])

      allow(UploadRedcapDetails).to receive(:construct_redcap_response).and_return(:response)
      actual = UploadRedcapDetails.question_answer_to_redcap_response(
        question_answer,
        false
      )
      expect(UploadRedcapDetails).to have_received(:construct_redcap_response).with(
        "11",
        "redcap_field_name",
        "yes",
        "multiple checkboxes",
        question_answer.user_id,
        false)
      expect(actual).to eq(:response)
    end
  end

  describe '#construct_redcap_response' do
    it 'returns nil when raw_redcap_field is blank' do
      actual = UploadRedcapDetails.construct_redcap_response(
        'my_raw_redcap_code',
        nil,
        'my_answer_string',
        'my_question_type',
        'my_user_id',
        false
      )
      expect(actual).to eq(nil)
    end

    it 'uses the answer string to determine the code when none is given' do
      allow(UploadRedcapDetails).to receive(:answer_string_to_code).and_return('my_answer_string')

      actual = UploadRedcapDetails.construct_redcap_response(
        nil,
        'my_raw_redcap_field',
        'yes',
        'my_question_type',
        'my_user_id',
        false
      )
      expect(actual).to eq([{'record_id' => 'my_user_id',
                             'my_raw_redcap_field' => 'my_answer_string'}])
    end

    it 'produces the correct response for question_type == "multiple checkboxes"' do
      actual_do_destroy = UploadRedcapDetails.construct_redcap_response(
        'my_raw_redcap_code',
        'my_raw_redcap_field',
        'my_answer_string',
        'multiple checkboxes',
        'my_user_id',
        true
      )
      actual_do_not_destroy = UploadRedcapDetails.construct_redcap_response(
        'my_raw_redcap_code',
        'my_raw_redcap_field',
        'my_answer_string',
        'multiple checkboxes',
        'my_user_id',
        false
      )
      expect(actual_do_destroy).to eq(
        [{'record_id' => 'my_user_id',
          'my_raw_redcap_field___my_raw_redcap_code' => '0'}])
      expect(actual_do_not_destroy).to eq(
        [{'record_id' => 'my_user_id',
          'my_raw_redcap_field___my_raw_redcap_code' => '1'}])
    end

    it 'produces the correct response for question_type != "multiple checkboxes"' do
      actual_do_destroy = UploadRedcapDetails.construct_redcap_response(
        'my_raw_redcap_code',
        'my_raw_redcap_field',
        'my_answer_string',
        'my_question_type',
        'my_user_id',
        true
      )
      actual_do_not_destroy = UploadRedcapDetails.construct_redcap_response(
        'my_raw_redcap_code',
        'my_raw_redcap_field',
        'my_answer_string',
        'my_question_type',
        'my_user_id',
        false
      )
      expect(actual_do_destroy).to eq(
        [{'record_id' => 'my_user_id',
          'my_raw_redcap_field' => 'my_raw_redcap_code'}])
      expect(actual_do_not_destroy).to eq(
        [{'record_id' => 'my_user_id',
          'my_raw_redcap_field' => 'my_raw_redcap_code'}])
    end
  end

  describe '#user_to_redcap_response' do
    it 'produces the correct response for UserColumnToRedcapFieldMapping.count == 0' do
      user = create(:user)
      expect(UploadRedcapDetails.user_to_redcap_response(user)).to eq(nil)
    end

    it 'produces the correct response for UserColumnToRedcapFieldMapping.count > 0' do
      user = create(:user)

      create(
        :user_column_to_redcap_field_mapping,
        user_column: 'dob',
        redcap_field: 'ctrl_dob',
        redcap_event_name: 'proband_informatio_arm_1'
      )
      create(
        :user_column_to_redcap_field_mapping,
        user_column: 'email',
        redcap_field: 'ctrl_email',
        redcap_event_name: 'proband_informatio_arm_1'
      )
      create(
        :user_column_to_redcap_field_mapping,
        user_column: 'is_parent',
        redcap_field: 'ctrl_is_parent',
        redcap_event_name: 'proband_informatio_arm_1'
      )
      create(
        :user_column_to_redcap_field_mapping,
        user_column: 'family_name',
        redcap_field: 'ctrl_family_name',
        redcap_event_name: ''
      )
      create(
        :user_column_to_redcap_field_mapping,
        user_column: 'state',
        redcap_field: 'ctrl_state',
        redcap_event_name: ''
      )

      actual = UploadRedcapDetails.user_to_redcap_response(user)
      expected = [
        {"record_id"=>user.id,
         "redcap_event_name"=>"proband_informatio_arm_1",
         "ctrl_dob"=>user.dob},
        {"record_id"=>user.id,
         "redcap_event_name"=>"proband_informatio_arm_1",
         "ctrl_email"=>user.email},
        {"record_id"=>user.id,
         "redcap_event_name"=>"proband_informatio_arm_1",
         "ctrl_is_parent"=>"1"},
        {"record_id"=>user.id,
         "ctrl_family_name"=>user.family_name},
      ]
      expect(actual).to eq(expected)
    end
  end

  describe '#perform' do
    it 'updates REDCap when there are updates to do' do
      allow(UploadRedcapDetails).to receive(:question_answer_to_redcap_response).and_return(:data)
      allow(UploadRedcapDetails).to receive(:make_redcap_api_payload).and_return(:payload)
      allow(UploadRedcapDetails).to receive(:call_api)
      UploadRedcapDetails.perform(:question_answer_to_redcap_response, 'id', false)
      expect(UploadRedcapDetails).to have_received(:make_redcap_api_payload).with(:data)
      expect(UploadRedcapDetails).to have_received(:call_api).with(:payload)
    end

    it 'does not update REDCap when there are no updates to do' do
      allow(UploadRedcapDetails).to receive(:question_answer_to_redcap_response).and_return(nil)
      allow(UploadRedcapDetails).to receive(:make_redcap_api_payload)
      allow(UploadRedcapDetails).to receive(:call_api)
      UploadRedcapDetails.perform(:question_answer_to_redcap_response, 'id', false)
      expect(UploadRedcapDetails).not_to have_received(:make_redcap_api_payload)
      expect(UploadRedcapDetails).not_to have_received(:call_api)
    end
  end

end
