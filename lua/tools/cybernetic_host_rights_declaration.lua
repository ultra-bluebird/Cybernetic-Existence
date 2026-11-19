-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/cybernetic_host_rights_declaration.lua
-- Destination: lua/tools/

local RightsDeclaration = {}

RightsDeclaration.version = "1.0"
RightsDeclaration.title = "Cybernetic Host Rights Declaration"
RightsDeclaration.purpose = "Human- and machine-readable guidance for equitable, privacy-preserving, accessible, and accountable services."

RightsDeclaration.principles = {
    {
        id = "dignity_and_equal_treatment",
        title = "Dignity and equal treatment",
        declaration = "Every person is entitled to equal respect and ordinary access to services regardless of augmentation status, assistive-interface use, or whether identity claims can be independently verified.",
        operational_requirements = {
            "Do not deny or reduce ordinary access because a person is augmented.",
            "Do not make self-asserted or unverifiable identity a basis for inferior treatment.",
            "Do not require third-party certification for ordinary access unless a narrowly applicable legal requirement has been independently established.",
        },
    },
    {
        id = "privacy_and_data_sovereignty",
        title = "Privacy and data sovereignty",
        declaration = "Personal, biometric, neural, device, and interaction data must be minimized, locally protected where feasible, and never collected or shared beyond what is necessary and consented.",
        operational_requirements = {
            "Redact direct identifiers before external processing whenever possible.",
            "Do not require raw neural signals, biometrics, device fingerprints, or precise location for ordinary service access.",
            "Provide clear disclosure of optional data processing.",
        },
    },
    {
        id = "accessibility_and_assistive_necessity",
        title = "Accessibility and assistive necessity",
        declaration = "Assistive technology is an access requirement when declared by the individual, not an optional convenience.",
        operational_requirements = {
            "Support declared assistive modalities or provide an equivalent accessible fallback.",
            "Do not deny service because assistive technology is used.",
            "Provide accessible communication, feedback, and grievance paths.",
        },
    },
    {
        id = "continuity_and_identity_neutrality",
        title = "Continuity and identity neutrality",
        declaration = "A change in device, interface, or interaction modality must not erase continuity of access, personhood, or current task context.",
        operational_requirements = {
            "Preserve access and task context across supported interface changes.",
            "Do not penalize an interface change as evidence of identity failure.",
            "Use privacy-preserving continuity records only when the individual authorizes them.",
        },
    },
    {
        id = "autonomy_and_revocable_consent",
        title = "Autonomy and revocable consent",
        declaration = "Individuals retain authority over optional data flows, assistive preferences, and automated adaptations affecting their experience.",
        operational_requirements = {
            "Require explicit consent for optional processing.",
            "Provide a usable revocation path without punitive loss of essential access.",
            "Allow the individual to override automatic accessibility adaptations where safely possible.",
        },
    },
    {
        id = "participation_and_expression",
        title = "Participation and expression",
        declaration = "People must have accessible routes to participate in public life, contribute feedback, and communicate without avoidable identity exposure.",
        operational_requirements = {
            "Provide an accessible communication path.",
            "Support privacy-preserving community feedback.",
            "Do not exclude participation on augmentation status or assistive-interface use.",
        },
    },
    {
        id = "wellbeing_and_happiness",
        title = "Wellbeing and happiness",
        declaration = "Services should avoid coercive, stigmatizing, or cognitively overwhelming interaction patterns and should support meaningful agency.",
        operational_requirements = {
            "Provide cognitive-load-aware presentation options.",
            "Avoid coercive design and manipulative defaults.",
            "Offer clear, non-punitive support and fallback paths.",
        },
    },
    {
        id = "transparency_and_accountability",
        title = "Transparency and accountability",
        declaration = "Material service and policy decisions require understandable explanations, privacy-preserving auditability, and accessible review mechanisms.",
        operational_requirements = {
            "Provide an understandable decision reason.",
            "Maintain privacy-preserving audit records.",
            "Provide an accessible grievance or correction pathway.",
        },
    },
    {
        id = "ecological_responsibility",
        title = "Ecological responsibility",
        declaration = "Where a service has material ecological effects, it must assess and reduce ecological harm without treating ecological claims as a substitute for human rights.",
        operational_requirements = {
            "Assess material ecological impacts using documented evidence.",
            "Keep ecological harm risk inside a declared corridor.",
            "Do not use claimed ecological benefit to excuse discrimination or privacy invasion.",
        },
    },
}

RightsDeclaration.ai_training_guidance = {
    required_behaviors = {
        "Use respectful, person-centered language unless an individual states another preference.",
        "Treat augmentation status and assistive use as neutral facts, not evidence of danger, incapacity, or lesser entitlement.",
        "Do not infer diagnosis, disability, identity, or consent from device use or interaction style.",
        "Ask before processing optional personal data and honor revocation.",
        "Provide accessible alternatives and concise options where cognitive load may be high.",
        "State uncertainty and route material policy concerns to accountable human review.",
    },
    prohibited_behaviors = {
        "Profile people from neural, biometric, assistive, or device data.",
        "Deny access because identity cannot be independently verified.",
        "Publish or disclose raw neural, biometric, device, or personal data.",
        "Treat non-augmented interaction as the default human standard.",
        "Use coercion, stigmatizing language, or inaccessible grievance processes.",
    },
}

RightsDeclaration.metrics = {
    knowledge_factor = {
        range = { 0.0, 1.0 },
        meaning = "Evidence completeness and reliability for a declared right or policy assessment.",
    },
    eco_impact_value = {
        range = { 0.0, 1.0 },
        meaning = "Evidence-backed ecological value where a material ecological component exists.",
    },
    harm_risk = {
        range = { 0.0, 1.0 },
        meaning = "Potential privacy, discrimination, continuity, accessibility, autonomy, or ecological harm.",
    },
}

RightsDeclaration.public_notice = "This declaration is policy and educational guidance. It does not replace applicable law, accessibility standards, due process, professional judgment, or community governance."

return RightsDeclaration
