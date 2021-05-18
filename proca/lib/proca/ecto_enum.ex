import EctoEnum
# Remember to update the GraphQL enums to match these!

defenum(ProcessingStatus, new: 0, confirming: 1, rejected: 2, accepted: 3, delivered: 4)

defenum(ExternalService, ses: "ses", sqs: "sqs", mailjet: "mailjet", wordpress: "wordpress")

defenum(ContactSchema, basic: 0, popular_initiative: 1, eci: 2, it_ci: 3)

defenum(DonateSchema, stripe_payment_intent: 0)

