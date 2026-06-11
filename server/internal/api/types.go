package api

// ParseRequest is the JSON body of POST /ai/parse.
type ParseRequest struct {
	Text       string   `json:"text"`
	Today      string   `json:"today"`
	Tone       string   `json:"tone"`
	Categories []string `json:"categories"`
	Wallets    []string `json:"wallets"`
}
