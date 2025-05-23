import React, { createContext, useContext, useMemo } from 'react';

const SectionContext = createContext();

export default function SectionProvider({
  children,
  section = [],
  disabled = false,
  allowIgnoreDisabled = true,
}) {
  const store = useMemo(() => [
    section,
    disabled,
    allowIgnoreDisabled,
  ], [section, disabled, allowIgnoreDisabled]);

  return (
    <SectionContext.Provider value={store}>
      {children}
    </SectionContext.Provider>
  );
}

export const useSections = () => useContext(SectionContext)[0];
export const useSectionDisabled = () => useContext(SectionContext)[1];
export const useSectionAllowIgnoreDisabled = () => useContext(SectionContext)[2];

const headAndTail = (arr) => {
  const safetyClone = [...arr];
  const shiftedHead = safetyClone.shift();

  return [shiftedHead, safetyClone];
};

export const readValueRecursive = (formValues, sectionKeys = []) => {
  if (sectionKeys.length === 0) {
    return formValues;
  }

  const [nextSection, tail] = headAndTail(sectionKeys);
  const nestedFormValues = formValues?.[nextSection] || {};

  return readValueRecursive(nestedFormValues, tail);
};
