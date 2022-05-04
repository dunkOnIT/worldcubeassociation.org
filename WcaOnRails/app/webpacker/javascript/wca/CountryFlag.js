import React from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import classnames from 'classnames';
import countries from './countries.js.erb';

const tooltipSettings = (tooltipText) => (
  <Tooltip id="resultCountryFlagTooptip">
    {tooltipText}
  </Tooltip>
);

/* eslint react/jsx-props-no-spreading: "off" */
function CountryFlag({ iso2, className, ...other }) {
  return (
    <OverlayTrigger overlay={tooltipSettings(countries.byIso2[iso2].name)} placement="top">
      <span {...other} className={classnames('flag-icon', `flag-icon-${iso2.toLowerCase()}`, className)} />
    </OverlayTrigger>
  );
}

export default CountryFlag;
