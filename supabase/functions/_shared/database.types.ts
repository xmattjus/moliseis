export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5";
  };
  public: {
    Tables: {
      cities: {
        Row: {
          created_at: string;
          deleted_at: string | null;
          description_delta: Json | null;
          id: number;
          modified_at: string;
          name: string;
        };
        Insert: {
          created_at?: string;
          deleted_at?: string | null;
          description_delta?: Json | null;
          id?: never;
          modified_at?: string;
          name: string;
        };
        Update: {
          created_at?: string;
          deleted_at?: string | null;
          description_delta?: Json | null;
          id?: never;
          modified_at?: string;
          name?: string;
        };
        Relationships: [];
      };
      content_submissions: {
        Row: {
          address: string | null;
          category: Database["public"]["Enums"]["content_category"];
          city: string;
          created_at: string;
          description: string | null;
          description_delta: Json | null;
          end_date: string | null;
          handled_at: string | null;
          handled_by: string | null;
          id: number;
          internal_notes: string | null;
          latitude: number | null;
          longitude: number | null;
          modified_at: string;
          name: string;
          rejection_reason: string | null;
          start_date: string | null;
          status: Database["public"]["Enums"]["submission_status"];
          status_email_attempted_at: string | null;
          status_email_key: string | null;
          status_email_last_error: string | null;
          status_email_message_id: string | null;
          status_email_sent_at: string | null;
          status_email_state: string | null;
          user_email: string;
          user_id: string;
          user_name: string;
        };
        Insert: {
          address?: string | null;
          category?: Database["public"]["Enums"]["content_category"];
          city: string;
          created_at?: string;
          description?: string | null;
          description_delta?: Json | null;
          end_date?: string | null;
          handled_at?: string | null;
          handled_by?: string | null;
          id?: never;
          internal_notes?: string | null;
          latitude?: number | null;
          longitude?: number | null;
          modified_at?: string;
          name: string;
          rejection_reason?: string | null;
          start_date?: string | null;
          status?: Database["public"]["Enums"]["submission_status"];
          status_email_attempted_at?: string | null;
          status_email_key?: string | null;
          status_email_last_error?: string | null;
          status_email_message_id?: string | null;
          status_email_sent_at?: string | null;
          status_email_state?: string | null;
          user_email: string;
          user_id: string;
          user_name: string;
        };
        Update: {
          address?: string | null;
          category?: Database["public"]["Enums"]["content_category"];
          city?: string;
          created_at?: string;
          description?: string | null;
          description_delta?: Json | null;
          end_date?: string | null;
          handled_at?: string | null;
          handled_by?: string | null;
          id?: never;
          internal_notes?: string | null;
          latitude?: number | null;
          longitude?: number | null;
          modified_at?: string;
          name?: string;
          rejection_reason?: string | null;
          start_date?: string | null;
          status?: Database["public"]["Enums"]["submission_status"];
          status_email_attempted_at?: string | null;
          status_email_key?: string | null;
          status_email_last_error?: string | null;
          status_email_message_id?: string | null;
          status_email_sent_at?: string | null;
          status_email_state?: string | null;
          user_email?: string;
          user_id?: string;
          user_name?: string;
        };
        Relationships: [];
      };
      events: {
        Row: {
          category: Database["public"]["Enums"]["content_category"];
          city_id: number | null;
          created_at: string;
          deleted_at: string | null;
          description: string | null;
          description_delta: Json | null;
          end_date: string | null;
          id: number;
          latitude: number;
          longitude: number;
          modified_at: string;
          name: string;
          start_date: string;
        };
        Insert: {
          category?: Database["public"]["Enums"]["content_category"];
          city_id?: number | null;
          created_at?: string;
          deleted_at?: string | null;
          description?: string | null;
          description_delta?: Json | null;
          end_date?: string | null;
          id?: never;
          latitude: number;
          longitude: number;
          modified_at?: string;
          name: string;
          start_date: string;
        };
        Update: {
          category?: Database["public"]["Enums"]["content_category"];
          city_id?: number | null;
          created_at?: string;
          deleted_at?: string | null;
          description?: string | null;
          description_delta?: Json | null;
          end_date?: string | null;
          id?: never;
          latitude?: number;
          longitude?: number;
          modified_at?: string;
          name?: string;
          start_date?: string;
        };
        Relationships: [
          {
            foreignKeyName: "events_city_id_fkey";
            columns: ["city_id"];
            isOneToOne: false;
            referencedRelation: "cities";
            referencedColumns: ["id"];
          },
        ];
      };
      media: {
        Row: {
          author: string | null;
          created_at: string;
          deleted_at: string | null;
          description: string | null;
          event_id: number | null;
          height: number;
          id: number;
          license: string | null;
          license_url: string | null;
          modified_at: string;
          place_id: number | null;
          url: string;
          width: number;
        };
        Insert: {
          author?: string | null;
          created_at?: string;
          deleted_at?: string | null;
          description?: string | null;
          event_id?: number | null;
          height: number;
          id?: never;
          license?: string | null;
          license_url?: string | null;
          modified_at?: string;
          place_id?: number | null;
          url: string;
          width: number;
        };
        Update: {
          author?: string | null;
          created_at?: string;
          deleted_at?: string | null;
          description?: string | null;
          event_id?: number | null;
          height?: number;
          id?: never;
          license?: string | null;
          license_url?: string | null;
          modified_at?: string;
          place_id?: number | null;
          url?: string;
          width?: number;
        };
        Relationships: [
          {
            foreignKeyName: "media_event_id_fkey";
            columns: ["event_id"];
            isOneToOne: false;
            referencedRelation: "events";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "media_place_id_fkey";
            columns: ["place_id"];
            isOneToOne: false;
            referencedRelation: "places";
            referencedColumns: ["id"];
          },
        ];
      };
      places: {
        Row: {
          category: Database["public"]["Enums"]["content_category"];
          city_id: number | null;
          created_at: string;
          deleted_at: string | null;
          description: string | null;
          description_delta: Json | null;
          id: number;
          latitude: number;
          longitude: number;
          modified_at: string;
          name: string;
        };
        Insert: {
          category?: Database["public"]["Enums"]["content_category"];
          city_id?: number | null;
          created_at?: string;
          deleted_at?: string | null;
          description?: string | null;
          description_delta?: Json | null;
          id?: never;
          latitude: number;
          longitude: number;
          modified_at?: string;
          name: string;
        };
        Update: {
          category?: Database["public"]["Enums"]["content_category"];
          city_id?: number | null;
          created_at?: string;
          deleted_at?: string | null;
          description?: string | null;
          description_delta?: Json | null;
          id?: never;
          latitude?: number;
          longitude?: number;
          modified_at?: string;
          name?: string;
        };
        Relationships: [
          {
            foreignKeyName: "places_city_id_fkey";
            columns: ["city_id"];
            isOneToOne: false;
            referencedRelation: "cities";
            referencedColumns: ["id"];
          },
        ];
      };
      submission_rate_limits: {
        Row: {
          submission_count: number;
          user_id: string;
          window_started_at: string;
        };
        Insert: {
          submission_count?: number;
          user_id: string;
          window_started_at: string;
        };
        Update: {
          submission_count?: number;
          user_id?: string;
          window_started_at?: string;
        };
        Relationships: [];
      };
      submissions_assets: {
        Row: {
          content_submission_id: number;
          duration_seconds: number | null;
          height: number;
          id: number;
          mime_type: string | null;
          url: string;
          width: number;
        };
        Insert: {
          content_submission_id: number;
          duration_seconds?: number | null;
          height: number;
          id?: never;
          mime_type?: string | null;
          url: string;
          width: number;
        };
        Update: {
          content_submission_id?: number;
          duration_seconds?: number | null;
          height?: number;
          id?: never;
          mime_type?: string | null;
          url?: string;
          width?: number;
        };
        Relationships: [
          {
            foreignKeyName: "submissions_assets_content_submission_id_fkey";
            columns: ["content_submission_id"];
            isOneToOne: false;
            referencedRelation: "content_submissions";
            referencedColumns: ["id"];
          },
        ];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      [_ in never]: never;
    };
    Enums: {
      content_category:
        | "unknown"
        | "nature"
        | "history"
        | "folklore"
        | "food"
        | "allure"
        | "experience";
      submission_status: "pending" | "accepted" | "rejected";
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">;

type DefaultSchema =
  DatabaseWithoutInternals[Extract<keyof Database, "public">];

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof (
      & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
        "Tables"
      ]
      & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
        "Views"
      ]
    )
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
} ? (
    & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Tables"
    ]
    & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Views"
    ]
  )[TableName] extends {
    Row: infer R;
  } ? R
  : never
  : DefaultSchemaTableNameOrOptions extends keyof (
    & DefaultSchema["Tables"]
    & DefaultSchema["Views"]
  ) ? (
      & DefaultSchema["Tables"]
      & DefaultSchema["Views"]
    )[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R;
    } ? R
    : never
  : never;

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Tables"
    ]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
} ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
    "Tables"
  ][TableName] extends {
    Insert: infer I;
  } ? I
  : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I;
    } ? I
    : never
  : never;

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Tables"
    ]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
} ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
    "Tables"
  ][TableName] extends {
    Update: infer U;
  } ? U
  : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U;
    } ? U
    : never
  : never;

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]][
      "Enums"
    ]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
} ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][
    EnumName
  ]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never;

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[
      PublicCompositeTypeNameOrOptions["schema"]
    ]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
} ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]][
    "CompositeTypes"
  ][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends
    keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never;

export const Constants = {
  public: {
    Enums: {
      content_category: [
        "unknown",
        "nature",
        "history",
        "folklore",
        "food",
        "allure",
        "experience",
      ],
      submission_status: ["pending", "accepted", "rejected"],
    },
  },
} as const;
