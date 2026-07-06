package events

import "errors"

var (
	ErrNotFound       = errors.New("event not found")
	ErrUnknownUserRef = errors.New("unknown user_ref")
)
