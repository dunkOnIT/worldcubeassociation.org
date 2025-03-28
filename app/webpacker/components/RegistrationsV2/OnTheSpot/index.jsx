import React, {
  useState,
} from 'react';
import _ from 'lodash';
import {
  Button,
  Form,
  Header,
  List,
  Message,
  Segment,
} from 'semantic-ui-react';
import WcaSearch from '../../SearchWidget/WcaSearch';
import SEARCH_MODELS from '../../SearchWidget/SearchModel';
import Loading from '../../Requests/Loading';
import RegistrationProvider, { useRegistration } from '../lib/RegistrationProvider';
import StoreProvider from '../../../lib/providers/StoreProvider';
import messageReducer from '../reducers/messageReducer';
import WCAQueryClientProvider from '../../../lib/providers/WCAQueryClientProvider';
import ConfirmProvider from '../../../lib/providers/ConfirmProvider';
import CompetingStep from '../Register/CompetingStep'

export default function Index({ competitionInfo }) {
  const [userToRegister, setUserToRegister] = useState({});

  const handleFormChange = (_, { name, value }) => setUserToRegister(
    { ...userToRegister, [name]: value },
  );

  return (
    <WCAQueryClientProvider>
      <StoreProvider reducer={messageReducer} initialState={{ messages: [] }}>
        <ConfirmProvider>
          <Header>
            Register a Returning Competitor
          </Header>
          <Form>
            <Form.Field
              label="Select User To Register"
              control={WcaSearch}
              name="user"
              onChange={handleFormChange}
              value={userToRegister.user}
              model={SEARCH_MODELS.user}
              multiple={false}
            />
          </Form>

          { userToRegister.user && (
            <RegistrationProvider
              competitionInfo={competitionInfo}
              userInfo={ userToRegister.user }
              isProcessing={false}
            >
              <CompetingStep
                nextStep={ { refresh: true } }
                competitionInfo={competitionInfo}
                user={ userToRegister.user }
                preferredEvents={[]}
                qualifications={[]}
              >
              </CompetingStep>
            </RegistrationProvider>
          )}

        </ConfirmProvider>
      </StoreProvider>
    </WCAQueryClientProvider>
  );
}
