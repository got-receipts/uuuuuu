from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class Platform(StrEnum):
    uber_eats = "Uber Eats"
    doordash = "DoorDash"
    grubhub = "Grubhub"
    instacart = "Instacart"
    amazon_flex = "Amazon Flex"
    other = "Other"


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class UserRead(BaseModel):
    id: int
    email: EmailStr
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserRead


class ShiftStart(BaseModel):
    platform: Platform
    started_at: datetime | None = None
    notes: str | None = None


class ShiftUpdate(BaseModel):
    platform: Platform | None = None
    started_at: datetime | None = None
    ended_at: datetime | None = None
    gross_earnings: Decimal | None = Field(default=None, ge=0)
    tips: Decimal | None = Field(default=None, ge=0)
    trips: int | None = Field(default=None, ge=0)
    miles: Decimal | None = Field(default=None, ge=0)
    gas_cost: Decimal | None = Field(default=None, ge=0)
    other_expenses: Decimal | None = Field(default=None, ge=0)
    active_minutes: int | None = Field(default=None, ge=0)
    notes: str | None = None


class ShiftCreate(ShiftUpdate):
    platform: Platform
    started_at: datetime
    ended_at: datetime | None = None


class ShiftEnd(ShiftUpdate):
    ended_at: datetime | None = None


class BreakStart(BaseModel):
    break_type: str = "rest"
    started_at: datetime | None = None
    notes: str | None = None


class BreakEnd(BaseModel):
    ended_at: datetime | None = None
    notes: str | None = None


class BreakRead(BaseModel):
    id: int
    shift_id: int
    started_at: datetime
    ended_at: datetime | None
    break_type: str
    notes: str | None

    model_config = ConfigDict(from_attributes=True)


class ShiftMetrics(BaseModel):
    total_minutes: int
    gross_hourly: Decimal
    net_hourly: Decimal
    earnings_per_mile: Decimal
    tax_set_aside: Decimal
    maintenance_reserve: Decimal
    net_profit: Decimal


class BreakStatus(BaseModel):
    level: str
    message: str
    suggested_minutes: int


class ShiftRead(BaseModel):
    id: int
    user_id: int
    started_at: datetime
    ended_at: datetime | None
    platform: str
    gross_earnings: Decimal
    tips: Decimal
    trips: int
    miles: Decimal
    gas_cost: Decimal
    other_expenses: Decimal
    active_minutes: int
    notes: str | None
    created_at: datetime
    updated_at: datetime
    breaks: list[BreakRead] = []
    metrics: ShiftMetrics
    break_status: BreakStatus

    model_config = ConfigDict(from_attributes=True)


class WeeklyReport(BaseModel):
    week_start: datetime
    week_end: datetime
    shifts: int
    online_minutes: int
    active_minutes: int
    gross_earnings: Decimal
    tips: Decimal
    trips: int
    miles: Decimal
    gas_cost: Decimal
    other_expenses: Decimal
    gross_hourly: Decimal
    net_hourly: Decimal
    earnings_per_mile: Decimal
    tax_set_aside: Decimal
    maintenance_reserve: Decimal
    net_profit: Decimal
