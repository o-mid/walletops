package auth

import "errors"

var (
	ErrEmailTaken     = errors.New("email taken")
	ErrInvalidRefresh = errors.New("invalid refresh token")
	ErrUserNotFound   = errors.New("user not found")
)
