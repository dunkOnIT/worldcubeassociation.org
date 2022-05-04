import React from 'react';

import { registerComponent } from '../wca/react-utils';
import OmnisearchInput from './OmnisearchInput';
import { omnisearchApiUrl } from '../requests/routes.js.erb';

function SearchWidget() {
  return (
    <OmnisearchInput
      removeNoResultsMessage
      goToItemOnSelect
      url={omnisearchApiUrl}
    />
  );
}

registerComponent(SearchWidget, 'SearchWidget');
