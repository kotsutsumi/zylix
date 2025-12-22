"""
Zylix Test Framework - Selector Builders
"""

from .types import Selector, SelectorStrategy


def by_test_id(test_id: str) -> Selector:
    """Create selector by test ID (data-testid attribute for web).

    Args:
        test_id: The test ID value

    Returns:
        Selector configured for test ID matching
    """
    return Selector(strategy=SelectorStrategy.TEST_ID, value=test_id)


def by_accessibility_id(accessibility_id: str) -> Selector:
    """Create selector by accessibility identifier.

    Args:
        accessibility_id: The accessibility identifier

    Returns:
        Selector configured for accessibility ID matching
    """
    return Selector(strategy=SelectorStrategy.ACCESSIBILITY_ID, value=accessibility_id)


def by_text(text: str) -> Selector:
    """Create selector by exact text match.

    Args:
        text: The exact text to match

    Returns:
        Selector configured for exact text matching
    """
    return Selector(strategy=SelectorStrategy.TEXT, value=text)


def by_text_contains(text: str) -> Selector:
    """Create selector by partial text match.

    Args:
        text: The text to search for

    Returns:
        Selector configured for partial text matching
    """
    return Selector(strategy=SelectorStrategy.TEXT_CONTAINS, value=text)


def by_xpath(xpath: str) -> Selector:
    """Create selector by XPath expression.

    Args:
        xpath: The XPath expression

    Returns:
        Selector configured for XPath matching
    """
    return Selector(strategy=SelectorStrategy.XPATH, value=xpath)


def by_css(css_selector: str) -> Selector:
    """Create selector by CSS selector (web only).

    Args:
        css_selector: The CSS selector

    Returns:
        Selector configured for CSS matching
    """
    return Selector(strategy=SelectorStrategy.CSS, value=css_selector)


def by_class_chain(class_chain: str) -> Selector:
    """Create selector by iOS class chain.

    Args:
        class_chain: The iOS class chain expression

    Returns:
        Selector configured for class chain matching
    """
    return Selector(strategy=SelectorStrategy.CLASS_CHAIN, value=class_chain)


def by_predicate(predicate: str) -> Selector:
    """Create selector by iOS predicate string.

    Args:
        predicate: The iOS predicate expression

    Returns:
        Selector configured for predicate matching
    """
    return Selector(strategy=SelectorStrategy.PREDICATE, value=predicate)


def by_ui_automator(ui_automator: str) -> Selector:
    """Create selector by Android UIAutomator expression.

    Args:
        ui_automator: The UIAutomator expression

    Returns:
        Selector configured for UIAutomator matching
    """
    return Selector(strategy=SelectorStrategy.UI_AUTOMATOR, value=ui_automator)


def by_role(role: str) -> Selector:
    """Create selector by accessibility role (macOS).

    Args:
        role: The accessibility role

    Returns:
        Selector configured for role matching
    """
    return Selector(strategy=SelectorStrategy.ROLE, value=role)


def to_webdriver_selector(selector: Selector) -> dict[str, str]:
    """Convert selector to WebDriver protocol format.

    Args:
        selector: The selector to convert

    Returns:
        Dictionary with 'using' and 'value' keys for WebDriver
    """
    strategy_map = {
        SelectorStrategy.TEST_ID: "css selector",
        SelectorStrategy.ACCESSIBILITY_ID: "accessibility id",
        SelectorStrategy.TEXT: "xpath",
        SelectorStrategy.TEXT_CONTAINS: "xpath",
        SelectorStrategy.XPATH: "xpath",
        SelectorStrategy.CSS: "css selector",
        SelectorStrategy.CLASS_CHAIN: "-ios class chain",
        SelectorStrategy.PREDICATE: "-ios predicate string",
        SelectorStrategy.UI_AUTOMATOR: "-android uiautomator",
        SelectorStrategy.ROLE: "accessibility id",
    }

    value = selector.value

    # Transform value based on strategy
    if selector.strategy == SelectorStrategy.TEST_ID:
        value = f'[data-testid="{selector.value}"]'
    elif selector.strategy == SelectorStrategy.TEXT:
        value = f'//*[text()="{selector.value}"]'
    elif selector.strategy == SelectorStrategy.TEXT_CONTAINS:
        value = f'//*[contains(text(), "{selector.value}")]'

    return {
        "using": strategy_map.get(selector.strategy, "xpath"),
        "value": value,
    }
