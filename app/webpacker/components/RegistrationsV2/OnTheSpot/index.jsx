import React, {
  useCallback, useEffect, useMemo, useState,
} from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import _ from 'lodash';
import updateRegistration from '../api/registration/patch/update_registration';
import submitEventRegistration from '../api/registration/post/submit_registration';
import Processing from '../Register/Processing';
import { contactCompetitionUrl, userPreferencesRoute } from '../../../lib/requests/routes.js.erb';
import EventSelector from '../../wca/EventSelector';
import { useDispatch } from '../../../lib/providers/StoreProvider';
import { showMessage } from '../Register/RegistrationMessage';
import I18n from '../../../lib/i18n';
import I18nHTMLTranslate from '../../I18nHTMLTranslate';
import { useConfirm } from '../../../lib/providers/ConfirmProvider';
import { events, defaultGuestLimit } from '../../../lib/wca-data.js.erb';
import { eventsNotQualifiedFor, isQualifiedForEvent } from '../../../lib/helpers/qualifications';
import { eventQualificationToString } from '../../../lib/utils/wcif';
import { hasNotPassed } from '../../../lib/utils/dates';
import { useRegistration } from '../lib/RegistrationProvider';
import useSet from '../../../lib/hooks/useSet';

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

export default function Index({ competitionInfo }) {
  const [userToRegister, setUserToRegister] = useState({});

  const handleFormChange = (_, { name, value }) => setUserToRegister(
    { ...userToRegister, [name]: value },
  );

  return (
    <>
      <Header>
        Register a Returning Competitor
      </Header>

      <Form onSubmit={handleSubmit} warning={formWarnings.length > 0} size="large">
        <Form.Field
          label="Select User To Register"
          control={WcaSearch}
          name="user"
          onChange={handleFormChange}
          value={userToRegister.user}
          model={SEARCH_MODELS.user}
          multiple={false}
        />
        <Message
          warning
          list={formWarnings}
        />
        <Form.Field required error={hasInteracted && selectedEventIds.size === 0}>
          <EventSelector
            id="event-selection"
            eventList={competitionInfo.event_ids}
            selectedEvents={selectedEventIds.asArray}
            onEventClick={onEventClick}
            onAllClick={onAllEventsClick}
            onClearClick={onClearEventsClick}
            maxEvents={maxEvents}
            eventsDisabled={
              competitionInfo.allow_registration_without_qualification
                ? []
                : eventsNotQualifiedFor(
                  competitionInfo.event_ids,
                  qualifications.wcif,
                  qualifications.personalRecords,
                )
            }
            disabledText={(event) => eventQualificationToString(
              { id: event },
              qualifications.wcif[event],
              { short: true },
            )}
            // Don't error if the user hasn't interacted with the form yet
            shouldErrorOnEmpty={hasInteracted}
          />
          {!competitionInfo.events_per_registration_limit
            && (
              <I18nHTMLTranslate
                options={{
                  link: `<a href="${userPreferencesRoute}">here</a>`,
                }}
                i18nKey="registrations.preferred_events_prompt_html"
              />
            )}
        </Form.Field>
        <Form.Field required={Boolean(competitionInfo.force_comment_in_registration)}>
          <label htmlFor="comment">
            {I18n.t('competitions.registration_v2.register.comment')}
            {' '}
            <div style={{ float: 'right', fontSize: '0.8em' }}>
              <i>
                (
                {comment.length}
                /
                {maxCommentLength}
                )
              </i>
            </div>
          </label>
          <Form.TextArea
            required={Boolean(competitionInfo.force_comment_in_registration)}
            maxLength={maxCommentLength}
            onChange={(event, data) => setComment(data.value)}
            value={comment}
            id="comment"
            error={competitionInfo.force_comment_in_registration && comment.trim().length === 0 && I18n.t('registrations.errors.cannot_register_without_comment')}
          />
        </Form.Field>
        {competitionInfo.guests_enabled && (
          <Form.Field>
            <label htmlFor="guest-dropdown">{I18n.t('activerecord.attributes.registration.guests')}</label>
            <Form.Input
              id="guest-dropdown"
              type="number"
              value={guests}
              onChange={(event, data) => {
                setGuests(Number.parseInt(data.value, 10));
              }}
              min="0"
              max={guestLimit}
              error={guestsRestricted && guests > guestLimit && I18n.t('competitions.competition_info.guest_limit', { count: guestLimit })}
            />
          </Form.Field>
        )}
        {isRegistered ? (
          <ButtonGroup widths={2}>
            {shouldShowUpdateButton && (
            <>
              <Button
                primary
                disabled={
                      isUpdating || !hasChanges
                    }
                type="submit"
              >
                {I18n.t('registrations.update')}
              </Button>
              <ButtonOr />
              <Button secondary onClick={() => nextStep()}>
                {I18n.t('competitions.registration_v2.register.view_registration')}
              </Button>
            </>
            )}

            {shouldShowReRegisterButton && (
            <Button
              primary
              disabled={isUpdating}
              type="submit"
            >
              {I18n.t('registrations.register')}
            </Button>
            )}
          </ButtonGroup>
        ) : (
          <>
            <Message info icon floating>
              <Popup
                content={I18n.t('registrations.mailer.new.awaits_approval')}
                position="top left"
                trigger={<Icon name="circle info" />}
              />
              <Message.Content>
                {I18n.t('competitions.registration_v2.register.disclaimer')}
              </Message.Content>
            </Message>
            <Button
              positive
              fluid
              icon
              type="submit"
              labelPosition="left"
              disabled={isCreating}
            >
              <Icon name="paper plane" />
              {I18n.t('registrations.register')}
            </Button>
          </>
        )}
      </Form>
    </>
  );
}
